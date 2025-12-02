use axum::{Json, Router, body::Bytes, http::StatusCode, routing::post};
use std::{
    fs::{OpenOptions, read_to_string},
    io::Write,
    path::PathBuf,
    process::Command,
    time::{SystemTime, UNIX_EPOCH},
};
use tower_http::{compression::CompressionLayer, services::ServeDir};

#[tokio::main]
async fn main() {
    let app = Router::new()
        .fallback_service(ServeDir::new("static"))
        .layer(CompressionLayer::new())
        .route("/execute", post(execute_code));

    let addr = "127.0.0.1:3000";
    println!("Listening on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

/// Execute Ruby code and return JSON holding its status.
async fn execute_code(body: Bytes) -> Result<Json<Option<String>>, StatusCode> {
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();

    let file_name = format!("{}_{}.rb", timestamp, std::process::id());

    let mut dir: PathBuf = std::env::temp_dir();
    dir.push(&file_name);

    let body_clone = body.clone();
    let output = tokio::task::spawn_blocking(move || {
        let mut file = OpenOptions::new()
            .read(true)
            .write(true)
            .truncate(true)
            .create(true)
            .open(&dir)
            .unwrap();

        file.write_all(&body_clone).unwrap();

        let mut child = Command::new("ruby")
            .args([
                "--zjit",
                "--zjit-call-threshold=2",
                "--zjit-dump-hir-iongraph",
                dir.to_str().unwrap(),
            ])
            .spawn()
            .expect("failed to wait on child");

        let cid = child.id();

        child.wait().unwrap();

        let mut s = String::new();
        let mut prefix = "";

        s.push_str("{\n\"functions\": [");

        if let Ok(foos) = std::fs::read_dir(format!("/tmp/zjit-iongraph-{}/", cid)) {
            for dir in foos.flatten() {
                let contents = read_to_string(dir.path()).expect("Couldn't read file");
                s.push_str(prefix);
                s.push_str(&contents);
                prefix = ",\n";
            }
        } else {
            return None;
        }

        s.push_str("],\n \"version\": 2\n }");

        Some(s)
    })
    .await
    .unwrap();

    Ok(Json(output))
}
