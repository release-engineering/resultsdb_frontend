# Copyright 2013, Red Hat, Inc
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Authors:
#   Josef Skladanka <jskladan@redhat.com>

import json

from cachelib.simple import SimpleCache
from flask import (
    Blueprint,
    Response,
    redirect,
    render_template,
    request,
    url_for,
)

from resultsdb_frontend import app
from resultsdb_frontend.resultsdb_api import ResultsDBapi

CACHE = SimpleCache()
CACHE_TIMEOUT = 60
RDB_API = ResultsDBapi(app.config["RDB_URL"])

main = Blueprint("main", __name__)


@main.route("/")
@main.route("/index")
def index():
    return redirect(url_for("main.results"))


@main.route("/testcase_tokenizer")
def testcase_tokenizer():
    global CACHE

    cached = CACHE.get("tokenized_testcases")
    if cached is not None:
        return cached
    page = 0
    tc_names = []
    while True:
        names = [
            tc["name"] for tc in RDB_API.get_testcases(page=page, limit=100)["data"]
        ]
        page += 1
        tc_names.extend(names)
        if not names:
            break
    data = sorted(tc_names, key=lambda x: (x.count("."), x))

    response = Response(
        response=json.dumps(data), status=200, mimetype="application/json"
    )
    CACHE.set("tokenized_testcases", response, CACHE_TIMEOUT)
    return response


@main.route("/groups")
def groups():
    groups = RDB_API.get_groups(**dict(request.args))
    return render_template("groups.html", groups=groups)


@main.route("/groups/<group_id>")
def group(group_id):
    group = RDB_API.get_group(group_id)
    groups = dict(prev=None, next=None, data=[group])
    return render_template("groups.html", groups=groups)


@main.route("/results")
def results():
    args = dict(request.args)
    results = RDB_API.get_results(**args)
    for result in results["data"]:
        result["groups"] = (len(result["groups"]), ",".join(result["groups"]))
    return render_template("results.html", results=results)


@main.route("/results/<result_id>")
def result(result_id):
    result = RDB_API.get_result(id=result_id)
    try:
        result["groups"] = (len(result["groups"]), ",".join(result["groups"]))
    except KeyError:
        result["groups"] = (0, "")
    return render_template("result_detail.html", result=result)


@main.route("/testcases")
def testcases():
    args = dict(request.args)
    tcs = RDB_API.get_testcases(**args)
    return render_template("testcases.html", testcases=tcs)


@main.route("/testcases/<path:testcase_name>")
def testcase(testcase_name):
    tc = RDB_API.get_testcase(name=testcase_name)
    tcs = dict(prev=None, next=None, data=[tc])
    return render_template("testcases.html", testcases=tcs)
