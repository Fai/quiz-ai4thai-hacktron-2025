use axum::{extract::Query, http::StatusCode, response::Json, routing::get, Router};
use serde::{Deserialize, Serialize};
use tower::ServiceBuilder;
use tower_http::{
    cors::{Any, CorsLayer},
    trace::TraceLayer,
};
use tracing::{error, info};
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize)]
struct TimeResponse {
    timestamp: String,
    timezone: String,
    request_id: String,
    source: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct ErrorResponse {
    error: String,
    request_id: String,
    timestamp: String,
}

#[derive(Debug, Deserialize)]
struct TimeQuery {
    timezone: Option<String>,
    request_id: Option<String>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter("api2=debug,tower_http=debug")
        .init();

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    // Create a function to build the router
    let create_app = || {
        Router::new()
            .route("/", get(root))
            .route("/health", get(health_check))
            .route("/time", get(get_time))
            .layer(
                ServiceBuilder::new()
                    .layer(TraceLayer::new_for_http())
                    .layer(cors.clone()),
            )
    };

    info!("API2 starting on ports 4000 (HTTP) and 4443 (HTTPS)");

    // Start HTTP server
    let http_listener = tokio::net::TcpListener::bind("0.0.0.0:4000").await?;
    info!("HTTP server listening on: {}", http_listener.local_addr()?);

    let http_app = create_app();
    tokio::spawn(async move {
        if let Err(e) = axum::serve(http_listener, http_app).await {
            error!("HTTP server error: {}", e);
        }
    });

    // Start HTTPS server (for production, you'd add TLS configuration)
    let https_listener = tokio::net::TcpListener::bind("0.0.0.0:4443").await?;
    info!(
        "HTTPS server listening on: {}",
        https_listener.local_addr()?
    );

    let https_app = create_app();
    axum::serve(https_listener, https_app).await?;

    Ok(())
}

async fn root() -> &'static str {
    "API2 - Time Service Provider"
}

async fn health_check() -> Json<serde_json::Value> {
    Json(serde_json::json!({
        "status": "healthy",
        "service": "api2",
        "timestamp": chrono::Utc::now().to_rfc3339()
    }))
}

async fn get_time(
    Query(params): Query<TimeQuery>,
) -> Result<Json<TimeResponse>, (StatusCode, Json<ErrorResponse>)> {
    let request_id = params
        .request_id
        .unwrap_or_else(|| Uuid::new_v4().to_string());
    let timezone = params.timezone.unwrap_or_else(|| "UTC".to_string());

    info!(
        request_id = %request_id,
        timezone = %timezone,
        "Processing time request"
    );

    // Get current time based on timezone
    let current_time = match timezone.as_str() {
        "UTC" => chrono::Utc::now().to_rfc3339(),
        "EST" | "US/Eastern" => chrono::Utc::now()
            .with_timezone(&chrono_tz::US::Eastern)
            .to_rfc3339(),
        "PST" | "US/Pacific" => chrono::Utc::now()
            .with_timezone(&chrono_tz::US::Pacific)
            .to_rfc3339(),
        "CET" | "Europe/Berlin" => chrono::Utc::now()
            .with_timezone(&chrono_tz::Europe::Berlin)
            .to_rfc3339(),
        _ => {
            // Default to UTC for unsupported timezones
            info!(
                request_id = %request_id,
                timezone = %timezone,
                "Unsupported timezone, defaulting to UTC"
            );
            chrono::Utc::now().to_rfc3339()
        }
    };

    let response = TimeResponse {
        timestamp: current_time.clone(),
        timezone: timezone.clone(),
        request_id: request_id.clone(),
        source: "api2-service".to_string(),
    };

    info!(
        request_id = %request_id,
        timestamp = %current_time,
        timezone = %timezone,
        "Time request processed successfully"
    );

    Ok(Json(response))
}
