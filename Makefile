#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2019, Joyent, Inc.
#

#
# Files, Tools, Var
#
JS_FILES := $(shell ls *.js 2>/dev/null) \
    $(shell find bin lib test -name '*.js' 2>/dev/null)

#XXX
# The next line breaks the build due to a variable that eng.git sed expander
# doesn't know about (@@ENABLED@@)
# SMF_MANIFESTS_IN = smf/manifests/amon-relay.xml.in

NODE_PREBUILT_VERSION=v6.17.0
NODE_PREBUILT_TAG=gz
ifeq ($(shell uname -s),SunOS)
	NODE_PREBUILT_IMAGE=c2c31b00-1d60-11e9-9a77-ff9f06554b0f
endif

# engbld includes
ENGBLD_REQUIRE := $(shell git submodule update --init deps/eng)
include ./deps/eng/tools/mk/Makefile.defs
TOP ?= $(error Unable to access eng.git submodule Makefiles.)
ifeq ($(shell uname -s),SunOS)
	include ./deps/eng/tools/mk/Makefile.node_prebuilt.defs
else
	NPM=npm
	NODE=node
	NPM_EXEC=$(shell which npm)
	NODE_EXEC=$(shell which node)
endif
include ./deps/eng/tools/mk/Makefile.smf.defs

NAME := amon-relay
RELEASE_TARBALL := $(NAME)-$(STAMP).tgz
RELEASE_MANIFEST := $(NAME)-$(STAMP).manifest
RELSTAGEDIR := /tmp/$(NAME)-$(STAMP)

#
# Due to the unfortunate nature of npm there appears to be no way to assemble
# our dependencies without running the lifecycle scripts. These lifecycle
# scripts should not be run except in the context of an agent installation or
# uninstallation, so we provide a magic environment varible to disable them
# here.
#
NPM_ENV =		SDC_AGENT_SKIP_LIFECYCLE=yes \
			MAKE_OVERRIDES='CTFCONVERT=/bin/true CTFMERGE=/bin/true'
RUN_NPM_INSTALL =	$(NPM_ENV) $(NPM) install

#
# Repo-specific targets
#
.PHONY: all
all: $(SMF_MANIFESTS) | $(NPM_EXEC)
	$(RUN_NPM_INSTALL)

CLEAN_FILES += node_modules npm-debug.log
DISTCLEAN_FILES += $(NAME)-*.manifest $(NAME)-*.tgz


# XXX tests
.PHONY: test
test:
	./test/runtests


.PHONY: release
release: all deps docs $(SMF_MANIFESTS)
	@echo "Building $(RELEASE_TARBALL)"
	@mkdir -p $(RELSTAGEDIR)/$(NAME)
	cp -Pr \
		$(TOP)/main.js \
		$(TOP)/bin \
		$(TOP)/lib \
		$(TOP)/node_modules \
		$(TOP)/package.json \
		$(TOP)/pkg \
		$(TOP)/smf \
		$(RELSTAGEDIR)/$(NAME)
	# Copy in and trim node build.
	@mkdir -p $(RELSTAGEDIR)/$(NAME)/build
	cp -Pr $(NODE_INSTALL) $(RELSTAGEDIR)/$(NAME)/build/node
	rm -rf \
	    $(RELSTAGEDIR)/$(NAME)/build/node/bin/npm \
	    $(RELSTAGEDIR)/$(NAME)/build/node/lib/node_modules \
	    $(RELSTAGEDIR)/$(NAME)/build/node/include \
	    $(RELSTAGEDIR)/$(NAME)/build/node/share
	uuid -v4 >$(RELSTAGEDIR)/$(NAME)/image_uuid
	cd $(RELSTAGEDIR) && $(TAR) -I pigz -cf $(TOP)/$(RELEASE_TARBALL) *
	cat $(TOP)/manifest.tmpl | sed \
	    -e "s/UUID/$$(cat $(RELSTAGEDIR)/$(NAME)/image_uuid)/" \
	    -e "s/NAME/$$(json name < $(TOP)/package.json)/" \
	    -e "s/VERSION/$$(json version < $(TOP)/package.json)/" \
	    -e "s/DESCRIPTION/$$(json description < $(TOP)/package.json)/" \
	    -e "s/BUILDSTAMP/$(STAMP)/" \
	    -e "s/SIZE/$$(stat --printf="%s" $(TOP)/$(RELEASE_TARBALL))/" \
	    -e "s/SHA/$$(openssl sha1 $(TOP)/$(RELEASE_TARBALL) | cut -d ' ' -f2)/" \
	    > $(TOP)/$(RELEASE_MANIFEST)
	@rm -rf $(RELSTAGEDIR)

.PHONY: publish
publish: release
	mkdir -p $(ENGBLD_BITS_DIR)/$(NAME)
	cp $(TOP)/$(RELEASE_TARBALL) $(ENGBLD_BITS_DIR)/$(NAME)/$(RELEASE_TARBALL)
	cp $(TOP)/$(RELEASE_MANIFEST) $(ENGBLD_BITS_DIR)/$(NAME)/$(RELEASE_MANIFEST)

# Here "cutting a release" is just tagging the current commit with
# "v(package.json version)". We don't publish this to npm.
.PHONY: cutarelease
cutarelease:
	@echo "# Ensure working copy is clean."
	[[ -z `git status --short` ]]  # If this fails, the working dir is dirty.
	@echo "# Ensure have 'json' tool."
	which json 2>/dev/null 1>/dev/null
	ver=$(shell cat package.json | json version) && \
	    date=$(shell date -u "+%Y-%m-%d") && \
	    git tag -a "v$$ver" -m "version $$ver ($$date)" && \
	    git push origin "v$$ver"

include ./deps/eng/tools/mk/Makefile.deps
ifeq ($(shell uname -s),SunOS)
	include ./deps/eng/tools/mk/Makefile.node_prebuilt.targ
endif
include ./deps/eng/tools/mk/Makefile.smf.targ
include ./deps/eng/tools/mk/Makefile.targ
