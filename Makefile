VERSION := $(shell yq e ".version" manifest.yaml)
ELECTRS_SRC := $(shell find ./electrs/src) electrs/Cargo.toml electrs/Cargo.lock
CONFIGURATOR_SRC := $(shell find ./configurator/src) configurator/Cargo.toml configurator/Cargo.lock
PKG_VERSION := $(shell yq e ".version" manifest.yaml)
PKG_ID := $(shell yq e ".id" manifest.yaml)
S9PK_PATH=$(shell find . -name electrs.s9pk -print)
TS_FILES := $(shell find . -name \*.ts )

.DELETE_ON_ERROR:

all: verify

verify: $(PKG_ID).s9pk
	embassy-sdk verify s9pk $(PKG_ID).s9pk

install: $(PKG_ID).s9pk
	embassy-cli package install $(PKG_ID).s9pk

clean:
	rm -f image.tar
	rm -f $(PKG_ID).s9pk
	rm -f scripts/*.js

$(PKG_ID).s9pk: manifest.yaml instructions.md scripts/embassy.js electrs/LICENSE docker-images/aarch64.tar docker-images/x86_64.tar
	if ! [ -z "$(ARCH)" ]; then cp docker-images/$(ARCH).tar image.tar; fi
	embassy-sdk pack

# image.tar: Dockerfile check*.sh docker_entrypoint.sh configurator/target/aarch64-unknown-linux-musl/release/configurator $(ELECTRS_SRC)
# 	DOCKER_CLI_EXPERIMENTAL=enabled docker buildx build --tag start9/electrs/main:$(VERSION) --platform=linux/arm64 -o type=docker,dest=image.tar .

docker-images/aarch64.tar: Dockerfile docker_entrypoint.sh configurator/target/aarch64-unknown-linux-musl/release/configurator $(ELECTRS_SRC)
	mkdir -p docker-images
	DOCKER_CLI_EXPERIMENTAL=enabled docker buildx build --tag start9/$(PKG_ID)/main:$(PKG_VERSION) --build-arg ARCH=aarch64 --build-arg PLATFORM=arm64 --platform=linux/arm64 -o type=docker,dest=docker-images/aarch64.tar .

docker-images/x86_64.tar: Dockerfile docker_entrypoint.sh configurator/target/x86_64-unknown-linux-musl/release/configurator $(ELECTRS_SRC)
	mkdir -p docker-images
	DOCKER_CLI_EXPERIMENTAL=enabled docker buildx build --tag start9/$(PKG_ID)/main:$(PKG_VERSION) --build-arg ARCH=x86_64 --build-arg PLATFORM=amd64 --platform=linux/amd64 -o type=docker,dest=docker-images/x86_64.tar .

configurator/target/aarch64-unknown-linux-musl/release/configurator: $(CONFIGURATOR_SRC)
	docker run --rm -it -v ~/.cargo/registry:/root/.cargo/registry -v "$(shell pwd)"/configurator:/home/rust/src start9/rust-musl-cross:aarch64-musl cargo build --release

configurator/target/x86_64-unknown-linux-musl/release/configurator: $(CONFIGURATOR_SRC)
	docker run --rm -it -v ~/.cargo/registry:/root/.cargo/registry -v "$(shell pwd)"/configurator:/home/rust/src start9/rust-musl-cross:x86_64-musl cargo build --release

scripts/embassy.js: $(TS_FILES)
	deno bundle scripts/embassy.ts scripts/embassy.js
