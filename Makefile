pwd = $(shell pwd)
build = $(pwd)/build/$(OS)_$(ARCH)
dist = $(pwd)/dist/$(OS)_$(ARCH)

ifeq ("${ARCH}", "386")
archflags = "-m32"
endif

version = 2.10.1
freetype = freetype-$(version)
zlib = zlib-1.2.11
libpng = libpng-1.6.37
harfbuzz = harfbuzz-2.5.3

define freetype_ar_script
create libfreetype.a
addlib $(build)/zlib/lib/libz.a
addlib $(build)/libpng/lib/libpng16.a
addlib $(build)/freetype/lib/libfreetype.a
save
endef
define freetypehb_ar_script
create libfreetypehb.a
addlib $(build)/zlib/lib/libz.a
addlib $(build)/libpng/lib/libpng16.a
addlib $(build)/harfbuzz/lib/libharfbuzz.a
addlib $(build)/freetype/lib/libfreetype.a
save
endef
export freetype_ar_script
export freetypehb_ar_script

ifeq ("${OS}", "linux")
goldflags = -ldflags "-linkmode external -extldflags -static"
endif

clean-zlib:
	rm -rf $(build)/zlib
build-zlib: clean-zlib
	mkdir -p $(build)/zlib
	cd src/$(zlib) \
		&& CFLAGS=$(archflags) ./configure --prefix=$(build)/zlib --static \
		&& make \
		&& make install

clean-libpng:
	rm -rf $(build)/libpng
build-libpng: clean-libpng build-zlib
	mkdir -p $(build)/libpng
	cd src/$(libpng) \
		&& LDFLAGS="-L$(build)/zlib/lib" CFLAGS=$(archflags) CPPFLAGS="-I $(build)/zlib/include $(archflags)" ./configure \
			--prefix=$(build)/libpng \
			--enable-static \
			--disable-shared \
			--with-zlib-prefix=$(build)/zlib \
		&& LD_LIBRARY_PATH=$(build)/zlib/lib CFLAGS=$(archflags) CPPFLAGS=$(archflags) make \
		&& make install

clean-freetype:
	rm -rf $(build)/freetype
build-freetype: clean-freetype build-libpng build-zlib
	mkdir -p $(build)/freetype
	cd src/$(freetype) \
		&& PKG_CONFIG_LIBDIR=$(build)/zlib/lib/pkgconfig:$(build)/libpng/lib/pkgconfig CFLAGS=$(archflags) ./configure \
			--prefix=$(build)/freetype \
			--enable-static \
			--disable-shared \
			--without-harfbuzz \
			--without-bzip2 \
		&& LD_LIBRARY_PATH=$(build)/zlib/lib:$(build)/libpng/lib make \
		&& make install

clean-harfbuzz:
	rm -rf $(build)/harfbuzz
build-harfbuzz: clean-harfbuzz build-libpng build-zlib build-freetype
	mkdir -p $(build)/harfbuzz
	cd src/$(harfbuzz) \
		&& autoreconf --force --install \
		&& PKG_CONFIG_LIBDIR=$(build)/zlib/lib/pkgconfig:$(build)/libpng/lib/pkgconfig:$(build)/freetype/lib/pkgconfig CFLAGS=$(archflags) CXXFLAGS=$(archflags) ./configure \
			--prefix=$(build)/harfbuzz \
			--enable-static \
			--disable-shared \
			--without-glib \
			--without-gobject \
			--without-cairo \
			--without-fontconfig \
			--without-icu \
			--without-graphite2 \
			--with-freetype \
			--without-uniscribe \
			--without-directwrite \
			--without-coretext \
		&& CFLAGS=$(archflags) CXXFLAGS=$(archflags) LD_LIBRARY_PATH=$(build)/zlib/lib:$(build)/libpng/lib:$(build)/freetype/lib make \
		&& make install

clean-freetypehb:
	rm -rf $(build)/freetypehb
build-freetypehb: clean-freetypehb build-libpng build-zlib build-harfbuzz
	mkdir -p $(build)/freetypehb
	cd src/$(freetype) \
		&& PKG_CONFIG_LIBDIR=$(build)/zlib/lib/pkgconfig:$(build)/libpng/lib/pkgconfig:$(build)/harfbuzz/lib/pkgconfig CFLAGS=$(archflags) ./configure \
			--prefix=$(build)/freetypehb \
			--enable-static \
			--disable-shared \
			--with-harfbuzz \
			--without-bzip2 \
		&& LD_LIBRARY_PATH=$(build)/zlib/lib:$(build)/libpng/lib:$(build)/harfbuzz/lib make \
		&& make install

build: build-freetype build-freetypehb

clean-dist:
	rm -rf $(dist)
dist: build clean-dist
	mkdir -p $(dist)/lib
	cp -r $(build)/freetype/include $(dist)
ifeq ("${OS}", "linux")
	cd $(dist)/lib && echo "$$freetype_ar_script" | ar -M
	cd $(dist)/lib && echo "$$freetypehb_ar_script" | ar -M 
endif
ifeq ("${OS}", "darwin")
	libtool -static -o $(dist)/lib/libfreetype.a \
		$(build)/zlib/lib/libz.a \
		$(build)/libpng/lib/libpng16.a \
		$(build)/freetype/lib/libfreetype.a
	libtool -static -o $(dist)/lib/libfreetypehb.a \
		$(build)/zlib/lib/libz.a \
		$(build)/libpng/lib/libpng16.a \
		$(build)/harfbuzz/lib/libharfbuzz.a \
		$(build)/freetype/lib/libfreetype.a
endif
	cd $(dist) && zip -r $(HOME)/$(OS)_$(ARCH).zip .

test-ft:
	CGO_ENABLED=1 GOOS=$(OS) GOARCH=$(ARCH) go build -tags 'static' $(goldflags) -o static main.go
	./static $(version)
test-ft-hb:
	CGO_ENABLED=1 GOOS=$(OS) GOARCH=$(ARCH) go build -tags 'static harfbuzz' $(goldflags) -o statichb main.go
	./statichb $(version)
