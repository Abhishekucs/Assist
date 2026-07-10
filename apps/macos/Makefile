.PHONY: build install run release clean

build:
	scripts/build_app.sh debug

install:
	scripts/install_app.sh debug

run: install
	open "$$(cat .build/installed_app_path)"

release:
	scripts/package_dmg.sh release

clean:
	rm -rf .build
