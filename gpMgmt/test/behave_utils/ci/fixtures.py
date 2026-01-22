from behave import fixture
from gppylib.commands.base import Command


@fixture
def init_cluster(context):
    if "concourse_cluster" in set(context.config.tags):
        host_ip = dict()
        for host in ["cdw"] + ['sdw{}'.format(i) for i in range(1, 6+1)]:
            cmd = Command("get ip", "host {host} | grep 'has address' | head -n 1 | cut -d ' ' -f 4".format(host=host))
            cmd.run(validateAfter=True)
            host_ip[host] = cmd.get_stdout()
        for host, ip in host_ip.items():
            cmd = Command("set ip", """
                          gpssh -h cdw -h sdw1 -h sdw2 -h sdw3 -h sdw4 -h sdw5 -h sdw6 -e "sudo bash -c 'echo \"{ip} {host}\" >>/etc/hosts'"
                          """.format(host=host, ip=ip))
            cmd.run(validateAfter=True)
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
