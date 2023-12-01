import ballerina/toml;

const string DEPENDENCIES_TOML_FILE = "../../ballerina/Dependencies.toml";

type DependenciesTomlData record {|
    ProjectDetails ballerina;
    Package[] package;
|};

type Package record {|
    string org;
    string name;
    string version;
    Dependency[] dependencies?;
    Module[] modules?;
|};

type Module record {|
    string org;
    string packageName;
    string moduleName;
|};

type Dependency record {|
    string org;
    string name;
|};

type ProjectDetails record {|
    string dependencies\-toml\-version;
    string distribution\-version;
|};

public function getHTTPModuleVersion() returns string|error {
    map<json> tomlFile = check toml:readFile(DEPENDENCIES_TOML_FILE);
    DependenciesTomlData dependenciesTomlData = check (tomlFile.toJson()).fromJsonWithType();
    Package[] packages = dependenciesTomlData.package;
    Package httpModuleData = packages.filter(package => package.name == "http")[0];
    
    return httpModuleData.version;
}
