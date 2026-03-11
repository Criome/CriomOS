{ pkgs }:

let
  python = pkgs.python3Packages;

  litellm_proxy_extras = python.buildPythonPackage {
    pname = "litellm-proxy-extras";
    version = "0.4.53";
    pyproject = true;
    nativeBuildInputs = [ python.poetry-core ];
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/03/5f/b38f51af0d04c948b71f0fa110c495d8c987bfd8292765291670aceb1f3d/litellm_proxy_extras-0.4.53.tar.gz";
      sha256 = "0w3zsallya3lrcbq70zlzvk8pfib9rp74wa1sahd94qdi6l3zi92";
    };
  };

  litellm_enterprise = python.buildPythonPackage {
    pname = "litellm-enterprise";
    version = "0.1.33.post2";
    pyproject = true;
    nativeBuildInputs = [ python.poetry-core ];
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/b6/ce/b1c82d5fdca9e5bf133c723bc0d63672483175e315eccb3a90b065bcd60d/litellm_enterprise-0.1.33.post2.tar.gz";
      sha256 = "14dd3h927xqmbm4dccw9kpcp0gaw9amdcwmarqqvmrl30lyqzfs7";
    };
  };

  baseDeps = with python; [
    fastuuid
    httpx
    openai
    python-dotenv
    tiktoken
    tokenizers
    click
    jinja2
    aiohttp
    pydantic
    jsonschema
    importlib-metadata
  ];

  proxyDeps = with python; [
    gunicorn
    uvicorn
    uvloop
    fastapi
    backoff
    pyyaml
    rq
    orjson
    apscheduler
    fastapi-sso
    pyjwt
    python-multipart
    cryptography
    pynacl
    websockets
    boto3
    azure-identity
    azure-storage-blob
    mcp
    rich
    polars
    soundfile
  ];

in
python.buildPythonApplication {
  pname = "litellm-proxy";
  version = "1.82.1";
  pyproject = true;
  nativeBuildInputs = [ python.poetry-core ];

  src = pkgs.fetchurl {
    url = "https://files.pythonhosted.org/packages/34/bd/6251e9a965ae2d7bc3342ae6c1a2d25dd265d354c502e63225451b135016/litellm-1.82.1.tar.gz";
    sha256 = "140q51yimh1sxcwrhy5gs4l77clk3iiwsvz310g1k7n9rk6jg15w";
  };

  propagatedBuildInputs = baseDeps ++ proxyDeps ++ [ litellm_proxy_extras litellm_enterprise ];
}
