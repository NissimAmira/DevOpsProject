"""Flask app for returning Hello World and GREETING values."""

import os
from flask import Flask, Response
from prometheus_client import Counter, Histogram, generate_latest, REGISTRY
import time

app = Flask(__name__)

# Define Prometheus metrics
REQUEST_COUNT = Counter(
    'flask_app_request_count',
    'Total number of requests',
    ['method', 'route', 'http_status']
)

REQUEST_LATENCY = Histogram(
    'flask_app_request_latency_seconds',
    'Request latency in seconds',
    ['method', 'route']
)

@app.before_request
def before_request():
    """Record request start time."""
    from flask import g
    g.start_time = time.time()

@app.after_request
def after_request(response):
    """Record metrics after each request."""
    from flask import g, request

    # Calculate request duration
    if hasattr(g, 'start_time'):
        request_latency = time.time() - g.start_time
        REQUEST_LATENCY.labels(
            method=request.method,
            route=request.endpoint or 'unknown'
        ).observe(request_latency)

    # Record request count
    REQUEST_COUNT.labels(
        method=request.method,
        route=request.endpoint or 'unknown',
        http_status=response.status_code
    ).inc()

    return response

@app.route('/')
def index():
    """Return Hello World."""
    return 'Hello World!'

@app.route('/hello')
def hello():
    """Return greeting from ConfigMap or Secret."""
    greeting = os.environ.get('GREETING', 'Hello')
    secret = os.environ.get('SECRET_MESSAGE', 'No secret')
    return f"{greeting}! Secret: {secret}"

@app.route('/metrics')
def metrics():
    """Return Prometheus metrics."""
    return Response(generate_latest(REGISTRY), mimetype='text/plain')

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000)
