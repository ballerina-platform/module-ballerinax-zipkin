import ballerina/http;
import ballerina/test;
import ballerina/lang.runtime;

public type Span record {|
    string traceId;
    string parentId?;
    string id;
    string kind;
    string name;
    int timestamp;
    int duration;
    json localEndpoint;
    json[] annotations?;
    map<string> tags;
|};

type TracePayload Span[][];

type Trace Span[];

type SpanNames string[];


http:Client zipkinClient = check new (string `http://localhost:9411`);
http:Client cl = check new (string `http://localhost:9091`);
http:Response res = new();

Span getSumSpan = {
    traceId: "",
    parentId: "",
    id: "",
    kind: "",
    name: "",
    timestamp: 0,
    duration: 0,
    localEndpoint: {},
    annotations: [],
    tags: {}
};

Span observableAdderSpan = {
    traceId: "",
    parentId: "",
    id: "",
    kind: "",
    name: "",
    timestamp: 0,
    duration: 0,
    localEndpoint: {},
    annotations: [],
    tags: {}
};
Span httpCallerSpan = {
    traceId: "",
    parentId: "",
    id: "",
    kind: "",
    name: "",
    timestamp: 0,
    duration: 0,
    localEndpoint: {},
    annotations: [],
    tags: {}
};

Span clientSpan = {
    traceId: "",
    parentId: "",
    id: "",
    kind: "",
    name: "",
    timestamp: 0,
    duration: 0,
    localEndpoint: {},
    annotations: [],
    tags: {}
};

Span httpClientSpan = {
    traceId: "",
    parentId: "",
    id: "",
    kind: "",
    name: "",
    timestamp: 0,
    duration: 0,
    localEndpoint: {},
    annotations: [],
    tags: {}
};

Span httpCachingClientSpan = {
    traceId: "",
    parentId: "",
    id: "",
    kind: "",
    name: "",
    timestamp: 0,
    duration: 0,
    localEndpoint: {},
    annotations: [],
    tags: {}
};

@test:BeforeSuite
function sendRequest() returns error? {
    res = check cl->get("/test/sum");
    runtime:sleep(5);

    json traces = check zipkinClient->get("/api/v2/traces?serviceName=%2Ftest&limit=10");
    TracePayload tracePayload = check traces.fromJsonWithType(TracePayload);
    Trace traceArray = tracePayload[0];

    Span[] spanArray = traceArray.filter(function (Span t) returns boolean {
        return t.name == "get /sum";
    });
    if (spanArray.length() > 0) {
        getSumSpan = spanArray[0];
    }

    spanArray = traceArray.filter(function (Span t) returns boolean {
        return t.name == "ballerinax/zipkin_server_tests/observableadder:getsum";
    });
    if (spanArray.length() > 0) {
        observableAdderSpan = spanArray[0];
    }

    spanArray = traceArray.filter(function (Span t) returns boolean {
        return t.name == "ballerina/http/caller:respond";
    });
    if (spanArray.length() > 0) {
        httpCallerSpan = spanArray[0];
    }

    spanArray = traceArray.filter(function (Span t) returns boolean {
        return t.name == "ballerina/http/client:get";
    });
    if (spanArray.length() > 0) {
        clientSpan = spanArray[0];
    }

    spanArray = traceArray.filter(function (Span t) returns boolean {
        return t.name == "ballerina/http/httpclient:get";
    });
    if (spanArray.length() > 0) {
        httpClientSpan = spanArray[0];
    }

    spanArray = traceArray.filter(function (Span t) returns boolean {
        return t.name == "ballerina/http/httpcachingclient:get";
    });
    if (spanArray.length() > 0) {
        httpCachingClientSpan = spanArray[0];
    }
}

@test:Config
function testResponse() returns error? {
    test:assertEquals(res.statusCode, http:STATUS_OK, "Status code mismatched");
    test:assertEquals(res.getTextPayload(), "Sum: 53", "Payload mismatched");
}

@test:Config
function testServices() returns error? {
    json services = check zipkinClient->get("/api/v2/services");
    test:assertTrue(services.toString().includes("/test"));
    test:assertTrue(services.toString().includes("ballerina"));
}

@test:Config
function testSpanNames() returns error? {
    json testEndpointSpans = check zipkinClient->get("/api/v2/spans?serviceName=%2Ftest");
    SpanNames testEndpointSpanNames = check testEndpointSpans.fromJsonWithType(SpanNames);

    test:assertTrue(isContain(testEndpointSpanNames, "ballerina/http/caller:respond"));
    test:assertTrue(isContain(testEndpointSpanNames, "get /sum"));
    test:assertTrue(isContain(testEndpointSpanNames, "ballerinax/zipkin_server_tests/observableadder:getsum"));

    json ballerinaEndpointSpans = check zipkinClient->get("/api/v2/spans?serviceName=ballerina");
    SpanNames ballerinaEndpointSpanNames = check ballerinaEndpointSpans.fromJsonWithType(SpanNames);

    test:assertTrue(isContain(ballerinaEndpointSpanNames, "ballerina/http/client:get"));
    test:assertTrue(isContain(ballerinaEndpointSpanNames, "ballerina/http/httpcachingclient:get"));
    test:assertTrue(isContain(ballerinaEndpointSpanNames, "ballerina/http/httpclient:get"));
}

@test:Config
function testTraces() returns error? {
    test:assertTrue(getSumSpan.name == "get /sum", "Trace with name: \"get /sum\" not found");
    test:assertTrue(observableAdderSpan.name == "ballerinax/zipkin_server_tests/observableadder:getsum",
        "Trace with name: \"ballerinax/zipkin_server_tests/observableadder:getsum\" not found");
    test:assertTrue(httpCallerSpan.name == "ballerina/http/caller:respond", "Trace with name: \"ballerina/http/caller:respond\" not found");
    test:assertTrue(clientSpan.name == "ballerina/http/client:get", "Trace with name: \"ballerina/http/client:get\" not found");
    test:assertTrue(httpClientSpan.name == "ballerina/http/httpclient:get", "Trace with name: \"ballerina/http/httpclient:get\" not found");
    test:assertTrue(httpCachingClientSpan.name == "ballerina/http/httpcachingclient:get", "Trace with name: \"ballerina/http/httpcachingclient:get\" not found");

    test:assertEquals(getSumSpan.kind, "SERVER", "Trace with name: \"get /sum\" is not a server trace");
    test:assertEquals(observableAdderSpan.kind, "CLIENT", "Trace with name: \"ballerinax/zipkin_server_tests/observableadder:getsum\" is not a client trace");
    test:assertEquals(httpCallerSpan.kind, "CLIENT", "Trace with name: \"ballerina/http/caller:respond\" is not a client trace");
    test:assertEquals(clientSpan.kind, "CLIENT", "Trace with name: \"ballerina/http/client:get\" is not a client trace");
    test:assertEquals(httpClientSpan.kind, "CLIENT", "Trace with name: \"ballerina/http/httpclient:get\" is not a client trace");
    test:assertEquals(httpCachingClientSpan.kind, "CLIENT", "Trace with name: \"ballerina/http/httpcachingclient:get\" is not a client trace");
}

@test:Config
function testSpanInheritance() returns error? {
    test:assertEquals(clientSpan.id, httpCachingClientSpan.parentId, "ParentId mismatched");
    test:assertEquals(httpCachingClientSpan.id, httpClientSpan.parentId, "ParentId mismatched");
    test:assertEquals(httpClientSpan.id, getSumSpan.parentId, "ParentId mismatched");
    test:assertEquals(getSumSpan.id, observableAdderSpan.parentId, "ParentId mismatched");
    test:assertEquals(getSumSpan.id, httpCallerSpan.parentId, "ParentId mismatched");
}

@test:Config
function testGetSumSpanTags() returns error? {
    map<string> getSumSpanTags = getSumSpan.tags;
    string[] getSumSpanTagKeys = getSumSpanTags.keys();

    test:assertTrue(containsTag("entrypoint.function.module", getSumSpanTagKeys));
    test:assertEquals(getSumSpanTags["entrypoint.function.module"], "ballerinax/zipkin_server_tests:0.1.0");
    test:assertTrue(containsTag("entrypoint.function.name", getSumSpanTagKeys));
    test:assertEquals(getSumSpanTags["entrypoint.function.name"], "/sum");
    test:assertTrue(containsTag("entrypoint.resource.accessor", getSumSpanTagKeys));
    test:assertEquals(getSumSpanTags["entrypoint.resource.accessor"], "get");
    test:assertTrue(containsTag("entrypoint.service.name", getSumSpanTagKeys));
    test:assertEquals(getSumSpanTags["entrypoint.service.name"], "/test");
    test:assertTrue(containsTag("http.method", getSumSpanTagKeys));
    test:assertEquals(getSumSpanTags["http.method"], http:GET);
    test:assertTrue(containsTag("http.status_code", getSumSpanTagKeys));
    test:assertEquals(getSumSpanTags["http.status_code"], http:STATUS_OK.toString());
    test:assertTrue(containsTag("http.url", getSumSpanTagKeys));
    test:assertEquals(getSumSpanTags["http.url"], "/test/sum");
    test:assertTrue(containsTag("listener.name", getSumSpanTagKeys));
    test:assertEquals(getSumSpanTags["listener.name"], "http");
    test:assertTrue(containsTag("otel.library.name", getSumSpanTagKeys));
    test:assertEquals(getSumSpanTags["otel.library.name"], "zipkin");
    test:assertTrue(containsTag("protocol", getSumSpanTagKeys));
    test:assertEquals(getSumSpanTags["protocol"], "http");
    test:assertTrue(containsTag("span.kind", getSumSpanTagKeys));
    test:assertEquals(getSumSpanTags["span.kind"], "server");
    test:assertTrue(containsTag("src.module", getSumSpanTagKeys));
    test:assertEquals(getSumSpanTags["src.module"], "ballerinax/zipkin_server_tests:0.1.0");
    test:assertTrue(containsTag("src.object.name", getSumSpanTagKeys));
    test:assertEquals(getSumSpanTags["src.object.name"], "/test");
    test:assertTrue(containsTag("src.position", getSumSpanTagKeys));
    test:assertEquals(getSumSpanTags["src.position"], "main.bal:26:5");
    test:assertTrue(containsTag("src.resource.accessor", getSumSpanTagKeys));
    test:assertEquals(getSumSpanTags["src.resource.accessor"], "get");
    test:assertTrue(containsTag("src.resource.path", getSumSpanTagKeys));
    test:assertEquals(getSumSpanTags["src.resource.path"], "/sum");
    test:assertTrue(containsTag("src.service.resource", getSumSpanTagKeys));
    test:assertEquals(getSumSpanTags["src.service.resource"], "true");
}

@test:Config
function testObservableAdderSpanTags() returns error? {
    map<string> observableAdderSpanTags = observableAdderSpan.tags;
    string[] observableAdderSpanTagKeys = observableAdderSpanTags.keys();

    test:assertTrue(containsTag("entrypoint.function.module", observableAdderSpanTagKeys));
    test:assertEquals(observableAdderSpanTags["entrypoint.function.module"], "ballerinax/zipkin_server_tests:0.1.0");
    test:assertTrue(containsTag("entrypoint.function.name", observableAdderSpanTagKeys));
    test:assertEquals(observableAdderSpanTags["entrypoint.function.name"], "/sum");
    test:assertTrue(containsTag("entrypoint.resource.accessor", observableAdderSpanTagKeys));
    test:assertEquals(observableAdderSpanTags["entrypoint.resource.accessor"], "get");
    test:assertTrue(containsTag("entrypoint.service.name", observableAdderSpanTagKeys));
    test:assertEquals(observableAdderSpanTags["entrypoint.service.name"], "/test");
    test:assertTrue(containsTag("otel.library.name", observableAdderSpanTagKeys));
    test:assertEquals(observableAdderSpanTags["otel.library.name"], "zipkin");
    test:assertTrue(containsTag("span.kind", observableAdderSpanTagKeys));
    test:assertEquals(observableAdderSpanTags["span.kind"], "client");
    test:assertTrue(containsTag("src.function.name", observableAdderSpanTagKeys));
    test:assertEquals(observableAdderSpanTags["src.function.name"], "getSum");
    test:assertTrue(containsTag("src.module", observableAdderSpanTagKeys));
    test:assertEquals(observableAdderSpanTags["src.module"], "ballerinax/zipkin_server_tests:0.1.0");
    test:assertTrue(containsTag("src.object.name", observableAdderSpanTagKeys));
    test:assertEquals(observableAdderSpanTags["src.object.name"], "ballerinax/zipkin_server_tests/ObservableAdder");
    test:assertTrue(containsTag("src.position", observableAdderSpanTagKeys));
    test:assertEquals(observableAdderSpanTags["src.position"], "main.bal:28:19");
}

@test:Config
function testHttpCallerSpanTags() returns error? {
    map<string> httpCallerSpanTags = httpCallerSpan.tags;
    string[] httpCallerSpanTagKeys = httpCallerSpanTags.keys();

    test:assertTrue(containsTag("entrypoint.function.module", httpCallerSpanTagKeys));
    test:assertEquals(httpCallerSpanTags["entrypoint.function.module"], "ballerinax/zipkin_server_tests:0.1.0");
    test:assertTrue(containsTag("entrypoint.function.name", httpCallerSpanTagKeys));
    test:assertEquals(httpCallerSpanTags["entrypoint.function.name"], "/sum");
    test:assertTrue(containsTag("entrypoint.resource.accessor", httpCallerSpanTagKeys));
    test:assertEquals(httpCallerSpanTags["entrypoint.resource.accessor"], "get");
    test:assertTrue(containsTag("entrypoint.service.name", httpCallerSpanTagKeys));
    test:assertEquals(httpCallerSpanTags["entrypoint.service.name"], "/test");
    test:assertTrue(containsTag("http.status_code", httpCallerSpanTagKeys));
    test:assertEquals(httpCallerSpanTags["http.status_code"], http:STATUS_OK.toString());
    test:assertTrue(containsTag("otel.library.name", httpCallerSpanTagKeys));
    test:assertEquals(httpCallerSpanTags["otel.library.name"], "zipkin");
    test:assertTrue(containsTag("span.kind", httpCallerSpanTagKeys));
    test:assertEquals(httpCallerSpanTags["span.kind"], "client");
    test:assertTrue(containsTag("src.client.remote", httpCallerSpanTagKeys));
    test:assertEquals(httpCallerSpanTags["src.client.remote"], "true");
    test:assertTrue(containsTag("src.function.name", httpCallerSpanTagKeys));
    test:assertEquals(httpCallerSpanTags["src.function.name"], "respond");
    test:assertTrue(containsTag("src.module", httpCallerSpanTagKeys));
    test:assertEquals(httpCallerSpanTags["src.module"], "ballerinax/zipkin_server_tests:0.1.0");
    test:assertTrue(containsTag("src.object.name", httpCallerSpanTagKeys));
    test:assertEquals(httpCallerSpanTags["src.object.name"], "ballerina/http/Caller");
    test:assertTrue(containsTag("src.position", httpCallerSpanTagKeys));
    test:assertEquals(httpCallerSpanTags["src.position"], "main.bal:32:20");
}

@test:Config
function testClientSpanTags() returns error? {
    map<string> clientSpanTags = clientSpan.tags;
    string[] clientSpanTagKeys = clientSpanTags.keys();

    test:assertTrue(containsTag("entrypoint.function.module", clientSpanTagKeys));
    test:assertEquals(clientSpanTags["entrypoint.function.module"], "ballerinax/zipkin_server_tests:0.1.0");
    test:assertTrue(containsTag("entrypoint.function.name", clientSpanTagKeys));
    test:assertEquals(clientSpanTags["entrypoint.function.name"], "get");
    test:assertTrue(containsTag("http.base_url", clientSpanTagKeys));
    test:assertEquals(clientSpanTags["http.base_url"], "http://localhost:9091");
    test:assertTrue(containsTag("http.method", clientSpanTagKeys));
    test:assertEquals(clientSpanTags["http.method"], http:GET);
    test:assertTrue(containsTag("http.status_code", clientSpanTagKeys));
    test:assertEquals(clientSpanTags["http.status_code"], http:STATUS_OK.toString());
    test:assertTrue(containsTag("http.url", clientSpanTagKeys));
    test:assertEquals(clientSpanTags["http.url"], "/test/sum");
    test:assertTrue(containsTag("otel.library.name", clientSpanTagKeys));
    test:assertEquals(clientSpanTags["otel.library.name"], "zipkin");
    test:assertTrue(containsTag("span.kind", clientSpanTagKeys));
    test:assertEquals(clientSpanTags["span.kind"], "client");
    test:assertTrue(containsTag("src.client.remote", clientSpanTagKeys));
    test:assertEquals(clientSpanTags["src.client.remote"], "true");
    test:assertTrue(containsTag("src.function.name", clientSpanTagKeys));
    test:assertEquals(clientSpanTags["src.function.name"], "get");
    test:assertTrue(containsTag("src.module", clientSpanTagKeys));
    test:assertEquals(clientSpanTags["src.module"], "ballerinax/zipkin_server_tests:0.1.0");
    test:assertTrue(containsTag("src.object.name", clientSpanTagKeys));
    test:assertEquals(clientSpanTags["src.object.name"], "ballerina/http/Client");
    test:assertTrue(containsTag("src.position", clientSpanTagKeys));
    test:assertEquals(clientSpanTags["src.position"], "tests/test.bal:108:17");
}

@test:Config
function testHttpCachingClientSpanTags() returns error? {
    map<string> httpCachingClientSpanTags = httpCachingClientSpan.tags;
    string[] httpCachingClientSpanTagKeys = httpCachingClientSpanTags.keys();

    test:assertTrue(containsTag("entrypoint.function.module", httpCachingClientSpanTagKeys));
    test:assertEquals(httpCachingClientSpanTags["entrypoint.function.module"], "ballerinax/zipkin_server_tests:0.1.0");
    test:assertTrue(containsTag("entrypoint.function.name", httpCachingClientSpanTagKeys));
    test:assertEquals(httpCachingClientSpanTags["entrypoint.function.name"], "get");
    test:assertTrue(containsTag("otel.library.name", httpCachingClientSpanTagKeys));
    test:assertEquals(httpCachingClientSpanTags["otel.library.name"], "zipkin");
    test:assertTrue(containsTag("span.kind", httpCachingClientSpanTagKeys));
    test:assertEquals(httpCachingClientSpanTags["span.kind"], "client");
    test:assertTrue(containsTag("src.client.remote", httpCachingClientSpanTagKeys));
    test:assertEquals(httpCachingClientSpanTags["src.client.remote"], "true");
    test:assertTrue(containsTag("src.function.name", httpCachingClientSpanTagKeys));
    test:assertEquals(httpCachingClientSpanTags["src.function.name"], "get");
    test:assertTrue(containsTag("src.module", httpCachingClientSpanTagKeys));
    test:assertEquals(httpCachingClientSpanTags["src.module"], "ballerina/http:2.10.0");
    test:assertTrue(containsTag("src.object.name", httpCachingClientSpanTagKeys));
    test:assertEquals(httpCachingClientSpanTags["src.object.name"], "ballerina/http/HttpCachingClient");
    test:assertTrue(containsTag("src.position", httpCachingClientSpanTagKeys));
    test:assertEquals(httpCachingClientSpanTags["src.position"], "http_client_endpoint.bal:282:41");
}

@test:Config
function testHttpClientSpanTags() returns error? {
    map<string> httpClientSpanTags = httpClientSpan.tags;
    string[] httpClientSpanTagKeys = httpClientSpanTags.keys();

    test:assertTrue(containsTag("entrypoint.function.module", httpClientSpanTagKeys));
    test:assertEquals(httpClientSpanTags["entrypoint.function.module"], "ballerinax/zipkin_server_tests:0.1.0");
    test:assertTrue(containsTag("entrypoint.function.name", httpClientSpanTagKeys));
    test:assertEquals(httpClientSpanTags["entrypoint.function.name"], "get");
    test:assertTrue(containsTag("http.method", httpClientSpanTagKeys));
    test:assertEquals(httpClientSpanTags["http.method"], http:GET);
    test:assertTrue(containsTag("http.status_code", httpClientSpanTagKeys));
    test:assertEquals(httpClientSpanTags["http.status_code"], http:STATUS_OK.toString());
    test:assertTrue(containsTag("http.url", httpClientSpanTagKeys));
    test:assertEquals(httpClientSpanTags["http.url"], "/test/sum");
    test:assertTrue(containsTag("otel.library.name", httpClientSpanTagKeys));
    test:assertEquals(httpClientSpanTags["otel.library.name"], "zipkin");
    test:assertTrue(containsTag("peer.address", httpClientSpanTagKeys));
    test:assertEquals(httpClientSpanTags["peer.address"], "localhost:9091");
    test:assertTrue(containsTag("span.kind", httpClientSpanTagKeys));
    test:assertEquals(httpClientSpanTags["span.kind"], "client");
    test:assertTrue(containsTag("src.client.remote", httpClientSpanTagKeys));
    test:assertEquals(httpClientSpanTags["src.client.remote"], "true");
    test:assertTrue(containsTag("src.function.name", httpClientSpanTagKeys));
    test:assertEquals(httpClientSpanTags["src.function.name"], "get");
    test:assertTrue(containsTag("src.module", httpClientSpanTagKeys));
    test:assertEquals(httpClientSpanTags["src.module"], "ballerina/http:2.10.0");
    test:assertTrue(containsTag("src.object.name", httpClientSpanTagKeys));
    test:assertEquals(httpClientSpanTags["src.object.name"], "ballerina/http/HttpClient");
    test:assertTrue(containsTag("src.position", httpClientSpanTagKeys));
    test:assertEquals(httpClientSpanTags["src.position"], "caching_http_caching_client.bal:371:16");
}

function isContain(string[] array, string id) returns boolean {
    return array.indexOf(id) != ();
}

function containsTag(string tagKey, string[] traceTagKeys) returns boolean {
    foreach string key in traceTagKeys {
        if (key == tagKey) {
            return true;
        }
    }
    return false;
}
