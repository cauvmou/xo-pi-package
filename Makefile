.PHONY: deb clean

# CHANNEL=stable|latest (default stable) or VERSION=X.Y.Z.
BUILD_ARGS = $(if $(VERSION),--version $(VERSION),$(if $(CHANNEL),--channel $(CHANNEL)))

deb:
	./build.sh $(BUILD_ARGS)

clean:
	rm -rf work out
