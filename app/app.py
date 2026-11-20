import os

from flask import Flask, jsonify
from redis import Redis
from redis.exceptions import RedisError

app = Flask(__name__)

redis_host = os.getenv("REDIS_HOST", "redis")
redis_port = int(os.getenv("REDIS_PORT", "6379"))

database = Redis(
    host=redis_host,
    port=redis_port,
    decode_responses=True,
    socket_connect_timeout=2,
    socket_timeout=2,
)

COUNTER_KEY = "visit_count"


@app.get("/")
def index():
    visits = database.incr(COUNTER_KEY)

    return jsonify(
        application="Persistent Visit Counter",
        visits=visits,
        database=redis_host,
    )


@app.get("/count")
def count():
    visits = database.get(COUNTER_KEY)

    return jsonify(visits=int(visits or 0))


@app.get("/health")
def health():
    database.ping()

    return jsonify(
        status="healthy",
        database="connected",
    )


@app.errorhandler(RedisError)
def database_error(error):
    app.logger.warning("Redis operation failed: %s", error)

    return jsonify(
        status="unavailable",
        message="Database connection unavailable",
    ), 503
