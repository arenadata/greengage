from behave import fixture


@fixture
def init_cluster(context, concourse_cluster, segments=3):
    if concourse_cluster:
        segments_str = ','.join('sdw{}'.format(i) for i in range(1, segments+1))
        context.execute_steps(u"""
            Given the database is not running
            And a working directory of the test as '/data/gpdata'
            And the user runs command "rm -rf ~/gpAdminLogs/gpinitsystem*"
            And a cluster is created with mirrors on "cdw" and "{}"
        """.format(segments_str))
    else:
        context.execute_steps(u"Given a standard local demo cluster is created")
