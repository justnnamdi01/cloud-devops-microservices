from cloud_devops_microservices import __version__
from cloud_devops_microservices.main import hello


def test_version():
    assert __version__ == "0.1.0"


def test_hello():
    assert hello("Tester") == "Hello, Tester!"
