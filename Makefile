# https://github.com/golangci/golangci-lint
GOLANGCI_LINT_VERSION=1.55.0
# https://github.com/mvdan/gofumpt
GOFUMPT_VERSION=0.5.0
GOARCH=amd64
UNAME=$(shell uname -s)

GOFUMPT_BIN=/tmp/gofumpt-$(GOFUMPT_VERSION)
GOLANGCILINT_BIN=/tmp/golangci-lint-$(GOLANGCI_LINT_VERSION)

ifndef OS
	ifeq ($(UNAME), Linux)
		OS = linux
	else ifeq ($(UNAME), Darwin)
		OS = darwin
	endif
endif

.PHONY: all
all: deps fmt build test

.PHONY: deps
deps:
	go mod tidy
	@test -f $(GOFUMPT_BIN)      || curl -sLo $(GOFUMPT_BIN) https://github.com/mvdan/gofumpt/releases/download/v$(GOFUMPT_VERSION)/gofumpt_v$(GOFUMPT_VERSION)_$(OS)_$(GOARCH)
	@test -f $(GOLANGCILINT_BIN) || curl -sfL https://github.com/golangci/golangci-lint/releases/download/v$(GOLANGCI_LINT_VERSION)/golangci-lint-$(GOLANGCI_LINT_VERSION)-$(OS)-$(GOARCH).tar.gz | tar -xzOf - golangci-lint-$(GOLANGCI_LINT_VERSION)-$(OS)-$(GOARCH)/golangci-lint > $(GOLANGCILINT_BIN)
	@chmod +x $(GOLANGCILINT_BIN) $(GOFUMPT_BIN)

.PHONY: lint
lint:
	$(GOLANGCILINT_BIN) run ./... -c .golangci.yaml

.PHONY: fmt
fmt:
	@# - gofumpt is not included in the .golangci.yaml because it conflicts with imports https://github.com/golangci/golangci-lint/issues/1490#issuecomment-778782810
	@# - goimports is not turned on since it is used mostly by gofumpt internally
	gci -w --local fox.flant.com/sys/deckhouse-connect .
	$(GOFUMPT_BIN) -l -w -extra .
	$(GOLANGCILINT_BIN) run ./... -c .golangci.yaml --fix

	bun x prettier ./index.ts --write

.PHONY: test
test:
	go test ./...

.PHONY: generate
generate:
	templ generate
	mkdir -p ./static
	bun x tailwindcss -o ./static/index.css --minify
	bun build --minify ./index.ts --outfile=./static/index.js

.PHONY: build
build: generate
	GOOS="$(OS)" GOARCH="$(GOARCH)" go build -ldflags="-s -w" -o app .

.PHONY: ci
ci: deps lint
	tmpfile=$(mktemp /tmp/coverage-report.XXXXXX)
	go test -cover -coverprofile=${tmpfile} -vet=off ./pkg/... \
        && echo "Coverage: $(go tool cover -func  ${tmpfile} | grep total | awk '{print $3}')" \
        && echo "Success!" \
        || exit 1

.PHONY: clean
clean:
	rm -rf ./static/*
	rm -rf *_templ.go
