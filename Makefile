.PHONY: build-in-container build-binaries sock_stress clean
DEPS:=$(wildcard pkg/*.go) $(wildcard cmd/sock_stress/*.go) $(wildcard cmd/vsudd/*.go) Dockerfile.build Makefile

build-in-container: $(DEPS) clean
	@echo "+ $@"
	@docker build -t hyvsock-build -f ./Dockerfile.build .
	@docker run --rm \
		-v ${CURDIR}/bin:/go/src/github.com/khulnasoft-lab/hyvsock/bin \
		hyvsock-build

build-binaries: vsudd sock_stress
sock_stress: bin/sock_stress.darwin bin/sock_stress.linux bin/sock_stress.exe
vsudd: bin/vsudd.linux 

bin/vsudd.linux: $(DEPS)
	@echo "+ $@"
	GOOS=linux GOARCH=amd64 \
	go build -o $@ -buildmode pie --ldflags '-s -w -extldflags "-static"' \
		github.com/khulnasoft-lab/hyvsock/cmd/vsudd

bin/sock_stress.linux: $(DEPS)
	@echo "+ $@"
	GOOS=linux GOARCH=amd64 \
	go build -o $@ -buildmode pie --ldflags '-s -w -extldflags "-static"' \
		github.com/khulnasoft-lab/hyvsock/cmd/sock_stress

bin/sock_stress.darwin: $(DEPS)
	@echo "+ $@"
	GOOS=darwin GOARCH=amd64 \
	go build -o $@ --ldflags '-extldflags "-fno-PIC"' \
		github.com/khulnasoft-lab/hyvsock/cmd/sock_stress

bin/sock_stress.exe: $(DEPS)
	@echo "+ $@"
	GOOS=windows GOARCH=amd64 \
	go build -o $@ \
		github.com/khulnasoft-lab/hyvsock/cmd/sock_stress

# Target to build a bootable EFI ISO and kernel+initrd
khulnasoft-lab: build-in-container Dockerfile.khulnasoft-lab hvtest.yml
	$(MAKE) -C c build-in-container
	docker build -t hvtest-local -f Dockerfile.khulnasoft-lab .
	khulnasoft-lab build -format kernel+initrd,iso-efi hvtest.yml

clean:
	rm -rf bin c/build

fmt:
	@echo "+ $@"
	@gofmt -s -l . 2>&1 | grep -v ^vendor/ | xargs gofmt -s -l -w

lint:
	@echo "+ $@"
	$(if $(shell which golint || echo ''), , \
		$(error Please install golint))
	@test -z "$$(golint ./... 2>&1 | grep -v ^vendor/ | grep -v mock/ | tee /dev/stderr)"
