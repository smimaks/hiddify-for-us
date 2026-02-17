# .ONESHELL:
include dependencies.properties
MKDIR := mkdir -p
RM  := rm -rf
SEP :=/

ifeq ($(OS),Windows_NT)
    ifeq ($(IS_GITHUB_ACTIONS),)
		MKDIR := -mkdir
		RM := rmdir /s /q
		SEP:=\\
	endif
endif


BINDIR=libcore$(SEP)bin
ANDROID_OUT=android$(SEP)app$(SEP)libs
DESKTOP_OUT=libcore$(SEP)bin
GEO_ASSETS_DIR=assets$(SEP)core

CORE_PRODUCT_NAME=hiddify-core
CORE_NAME=$(CORE_PRODUCT_NAME)
LIB_NAME=libcore

ifeq ($(CHANNEL),prod)
	CORE_URL=https://github.com/hiddify/hiddify-next-core/releases/download/v$(core.version)
else
	CORE_URL=https://github.com/hiddify/hiddify-next-core/releases/download/draft
endif

ifeq ($(CHANNEL),prod)
	TARGET=lib/main_prod.dart
else
	TARGET=lib/main.dart
endif

BUILD_ARGS=
DISTRIBUTOR_ARGS=--skip-clean --build-target $(TARGET)



get:	
	flutter pub get

gen:
	dart run build_runner build --delete-conflicting-outputs

prepare:
	@echo use the following commands to prepare the library for each platform:
	@echo    make android-prepare
	@echo    make windows-prepare
	@echo    make linux-prepare

windows-prepare: get gen windows-libs

linux-prepare: get-geo-assets get gen linux-libs
linux-appimage-prepare:linux-prepare
linux-rpm-prepare:linux-prepare
linux-deb-prepare:linux-prepare

android-prepare: get-geo-assets get gen android-libs
android-apk-prepare:android-prepare
android-aab-prepare:android-prepare


.PHONY: protos
protos:
	make -C libcore -f Makefile protos
	protoc --dart_out=grpc:lib/singbox/generated --proto_path=libcore/protos libcore/protos/*.proto

android-install-dependencies: 
	echo "nothing yet"
android-apk-install-dependencies: android-install-dependencies
android-aab-install-dependencies: android-install-dependencies

linux-install-dependencies:
	if [ "$(flutter)" = "true" ]; then \
		mkdir -p ~/develop; \
		cd ~/develop; \
		wget -O flutter_linux-stable.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.19.4-stable.tar.xz; \
		tar xf flutter_linux-stable.tar.xz; \
		rm flutter_linux-stable.tar.xz;\
		export PATH="$$PATH:$$HOME/develop/flutter/bin"; \
		echo 'export PATH="$$PATH:$$HOME/develop/flutter/bin"' >> ~/.bashrc; \
	fi
	PATH="$$PATH":"$$HOME/.pub-cache/bin"
	echo 'export PATH="$$PATH:$$HOME/.pub-cache/bin"' >>~/.bashrc
	sudo apt-get update
	sudo apt install -y clang ninja-build pkg-config cmake libgtk-3-dev locate ninja-build pkg-config libglib2.0-dev libgio2.0-cil-dev libayatana-appindicator3-dev fuse rpm patchelf file appstream 
	
	
	sudo modprobe fuse
	wget -O appimagetool "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
	chmod +x appimagetool
	sudo mv appimagetool /usr/local/bin/

	dart pub global activate --source git  https://github.com/hiddify/flutter_distributor --git-path packages/flutter_distributor

windows-install-dependencies:
	dart pub global activate flutter_distributor

gen_translations:
	cd .github && bash sync_translate.sh

android-release: android-apk-release

android-apk-release:
	flutter build apk --target $(TARGET) $(BUILD_ARGS) --target-platform android-arm,android-arm64,android-x64 --split-per-abi --verbose
	ls -la build/app/outputs/flutter-apk/

android-apk-universal:
	flutter build apk --target $(TARGET) $(BUILD_ARGS) --verbose
	ls -la build/app/outputs/flutter-apk/

android-aab-release:
	flutter build appbundle --target $(TARGET) $(BUILD_ARGS) --dart-define release=google-play
	ls -R build/app/outputs

windows-release:
	flutter_distributor package --flutter-build-args=verbose --platform windows --targets exe,msix $(DISTRIBUTOR_ARGS)

linux-release: 
	flutter_distributor package --flutter-build-args=verbose --platform linux --targets deb,rpm,appimage $(DISTRIBUTOR_ARGS)

android-libs:
	@$(MKDIR) $(ANDROID_OUT) || echo Folder already exists. Skipping...
	curl -L $(CORE_URL)/$(CORE_NAME)-android.tar.gz | tar xz -C $(ANDROID_OUT)/

android-apk-libs: android-libs
android-aab-libs: android-libs

windows-libs:
	$(MKDIR) $(DESKTOP_OUT) || echo Folder already exists. Skipping...
	curl -L $(CORE_URL)/$(CORE_NAME)-windows-amd64.tar.gz | tar xz -C $(DESKTOP_OUT)$(SEP)
	ls $(DESKTOP_OUT) || dir $(DESKTOP_OUT)$(SEP)
	

linux-libs:
	mkdir -p $(DESKTOP_OUT)
	curl -L $(CORE_URL)/$(CORE_NAME)-linux-amd64.tar.gz | tar xz -C $(DESKTOP_OUT)/

get-geo-assets:
	echo ""
	# curl -L https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db -o $(GEO_ASSETS_DIR)/geoip.db
	# curl -L https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db -o $(GEO_ASSETS_DIR)/geosite.db

build-headers:
	make -C libcore -f Makefile headers && mv $(BINDIR)/$(CORE_NAME)-headers.h $(BINDIR)/libcore.h

build-android-libs:
	make -C libcore -f Makefile android 
	mv $(BINDIR)/$(LIB_NAME).aar $(ANDROID_OUT)/

build-windows-libs:
	make -C libcore -f Makefile windows-amd64

build-linux-libs:
	make -C libcore -f Makefile linux-amd64 

release: # Create a new tag for release.
	@CORE_VERSION=$(core.version) bash -c ".github/change_version.sh "
