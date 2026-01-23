from behave import fixture
from gppylib.commands.base import Command
import socket


@fixture
def init_cluster(context):
    if "concourse_cluster" in set(context.config.tags):
        hosts = ["cdw"] + ['sdw{}'.format(i) for i in range(1, 6+1)]
        for host in hosts:
            ip = socket.gethostbyname(host)
            name = "set {ip} and {host} to /etc/hosts".format(host=host, ip=ip)
            cmdStr = """
                gpssh -h {hosts} -e "sudo bash -c 'echo \"{ip} {host}\" >>/etc/hosts'"
            """.format(host=host, ip=ip, hosts=' -h '.join(hosts))
            Command(name, cmdStr).run(validateAfter=True)
        if "concourse_cluster_4" in set(context.feature.tags):
            segments = 4
        elif "concourse_cluster_2" in set(context.feature.tags):
            segments = 2
        else:
            segments = 3
        segments_str = ','.join('sdw{}'.format(i) for i in range(1, segments+1))
        context.execute_steps(u"""
            Given the database is not running
            And a working directory of the test as '/data/gpdata'
            And the user runs command "rm -rf ~/gpAdminLogs/gpinitsystem*"
            And a cluster is created with mirrors on "cdw" and "{}"
        """.format(segments_str))
    else:
        context.execute_steps(u"""
            Given the database is not running
            And the user runs command "rm -rf ~/gpAdminLogs/gpinitsystem*"
            And a standard local demo cluster is created
        """)
