import os
from flask import Flask

app = Flask(__name__)

@app.route('/')
def index():
    return 'Hello World!'

@app.route('/hello')
def hello():
    greeting = os.environ.get('GREETING', 'Hello')
    secret = os.environ.get('SECRET_MESSAGE', 'No secret')
    return f"{greeting}! Secret: {secret}"

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000)