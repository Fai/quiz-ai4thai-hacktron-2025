use axum::{extract::Query, http::StatusCode, response::Json, routing::get, Router};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::net::SocketAddr;
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
}

#[tokio::main]
async fn main() {
    // Initialize tracing
    let subscriber = tracing_subscriber::fmt()
        .with_env_filter("api1=debug,tower_http=debug")
        .finish();
    
    tracing::subscriber::set_global_default(subscriber)
        .expect("Failed to set tracing subscriber");
    
    println!("API1 starting up...");
    info!("API1 initializing");
    
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);
    
    println!("CORS layer created");
    
    // Create a function to build the router
    let app = Router::new()
        .route("/", get(root))
        .route("/health", get(health_check))
        .route("/time", get(get_time))
        .layer(
            ServiceBuilder::new()
                .layer(TraceLayer::new_for_http())
                .layer(cors),
        );

    info!("API1 starting on port 3000 (HTTP)");
    println!("API1 starting on port 3000 (HTTP)");

    // Bind to address
    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
    println!("Binding to {}", addr);
    
    // Start the server
    println!("Starting server...");
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    println!("Server listening on {}", addr);
    info!("HTTP server listening on: {}", addr);
    
    axum::serve(listener, app).await.unwrap();
}

async fn root() -> &'static str {
    "API1 - Time Service Gateway"
}

async fn health_check() -> Json<serde_json::Value> {
    Json(serde_json::json!({
        "status": "healthy",
        "service": "api1",
        "timestamp": chrono::Utc::now().to_rfc3339()
    }))
}

async fn get_time(
    Query(params): Query<TimeQuery>,
) -> Result<Json<TimeResponse>, (StatusCode, Json<ErrorResponse>)> {
    let request_id = Uuid::new_v4().to_string();
    let timezone = params.timezone.unwrap_or_else(|| "UTC".to_string());

    info!(
        request_id = %request_id,
        timezone = %timezone,
        "Received time request"
    );

    // Call API2 to get the actual time
    let api2_url = std::env::var("API2_URL").unwrap_or_else(|_| "http://api2:4000".to_string());
    let client = reqwest::Client::new();

    let mut query_params = HashMap::new();
    query_params.insert("timezone", timezone.clone());
    query_params.insert("request_id", request_id.clone());

    info!(
        request_id = %request_id,
        api2_url = %api2_url,
        "Forwarding request to API2"
    );

    match client
        .get(format!("{api2_url}/time"))
        .query(&query_params)
        .send()
        .await
    {
        Ok(response) => {
            if response.status().is_success() {
                match response.json::<TimeResponse>().await {
                    Ok(time_data) => {
                        info!(
                            request_id = %request_id,
                            timestamp = %time_data.timestamp,
                            "Successfully received response from API2"
                        );

                        let response = TimeResponse {
                            timestamp: time_data.timestamp,
                            timezone: time_data.timezone,
                            request_id: request_id.clone(),
                            source: "api1->api2".to_string(),
                        };

                        Ok(Json(response))
                    }
                    Err(e) => {
                        error!(
                            request_id = %request_id,
                            error = %e,
                            "Failed to parse response from API2"
                        );

                        Err((
                            StatusCode::INTERNAL_SERVER_ERROR,
                            Json(ErrorResponse {
                                error: "Failed to parse response from API2".to_string(),
                                request_id,
                                timestamp: chrono::Utc::now().to_rfc3339(),
                            }),
                        ))
                    }
                }
            } else {
                error!(
                    request_id = %request_id,
                    status = %response.status(),
                    "API2 returned error status"
                );

                Err((
                    StatusCode::BAD_GATEWAY,
                    Json(ErrorResponse {
                        error: format!("API2 returned status: {}", response.status()),
                        request_id,
                        timestamp: chrono::Utc::now().to_rfc3339(),
                    }),
                ))
            }
        }
        Err(e) => {
            error!(
                request_id = %request_id,
                error = %e,
                "Failed to connect to API2"
            );

            Err((
                StatusCode::SERVICE_UNAVAILABLE,
                Json(ErrorResponse {
                    error: "Failed to connect to API2".to_string(),
                    request_id,
                    timestamp: chrono::Utc::now().to_rfc3339(),
                }),
            ))
        }
    }
}
