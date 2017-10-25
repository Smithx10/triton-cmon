#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright 2017 Joyent, Inc.
#

#
# Makefile for CMON
#

# 'make check' vars
JS_FILES	:= ./bin/cmon $(shell find lib test -name '*.js')
JSSTYLE_FILES	= $(JS_FILES)
JSSTYLE_FLAGS	= -f tools/jsstyle.conf
JSL_FILES_NODE  = $(JS_FILES)
JSL_CONF_NODE   = tools/jsl.node.conf
ESLINT		= ./node_modules/.bin/eslint
ESLINT_CONF	= tools/eslint.node.conf
ESLINT_FILES	= $(JS_FILES)

SMF_MANIFESTS_IN = smf/manifests/cmon.xml.in

# sdcnode (aka prebuilt-node) vars
NODE_PREBUILT_VERSION=v4.8.5
NODE_PREBUILT_TAG=zone64
NODE_PREBUILT_IMAGE=18b094b0-eb01-11e5-80c1-175dac7ddf02

# eng.git Makefile includes. Use sdcnode on SunOS, but not other platforms.
include ./tools/mk/Makefile.defs
include ./tools/mk/Makefile.node_prebuilt.defs
ifeq ($(shell uname -s),SunOS)
	include ./tools/mk/Makefile.node_prebuilt.defs
else
	NPM=npm
	NODE=node
	NPM_EXEC=$(shell which npm)
	NODE_EXEC=$(shell which node)
endif
include ./tools/mk/Makefile.smf.defs

# other vars
NAME		:= cmon
RELEASE_TARBALL	:= $(NAME)-pkg-$(STAMP).tar.bz2
RELSTAGEDIR	:= /tmp/$(STAMP)
TAPE		= $(TOP)/node_modules/tape/bin/tape
CLEAN_FILES	+= ./node_modules

#
# Repo-specific targets
#
.PHONY: all
all: | $(REPO_DEPS) $(NPM_EXEC)
	$(NPM) install --production

$(TAPE): | $(NPM_EXEC)
	$(NPM) install

.PHONY: test
test: all | $(TAPE) $(NODE_EXEC)
	$(NODE) $(TAPE) test/*.test.js

.PHONY: release
release: all docs $(SMF_MANIFESTS) $(NODE_EXEC)
	@echo "Building $(RELEASE_TARBALL)"
	@mkdir -p $(RELSTAGEDIR)/root/opt/triton/$(NAME)
	cp -r   $(TOP)/bin \
		$(TOP)/lib \
		$(TOP)/node_modules \
		$(TOP)/package.json \
		$(TOP)/sapi_manifests \
		$(TOP)/test \
		$(TOP)/smf \
		$(RELSTAGEDIR)/root/opt/triton/cmon/
	@mkdir -p $(RELSTAGEDIR)/root/opt/triton/cmon/build
	cp -r   $(TOP)/build/node \
		$(RELSTAGEDIR)/root/opt/triton/cmon/build/
	@mkdir -p $(RELSTAGEDIR)/root/opt/smartdc/boot
	cp -R $(TOP)/node_modules/sdc-scripts/* $(RELSTAGEDIR)/root/opt/smartdc/boot/
	cp -R $(TOP)/boot/* $(RELSTAGEDIR)/root/opt/smartdc/boot/
	(cd $(RELSTAGEDIR) && $(TAR) -jcf $(TOP)/$(RELEASE_TARBALL) root)
	@rm -rf $(RELSTAGEDIR)

.PHONY: publish
publish: release
	@if [[ -z "$(BITS_DIR)" ]]; then \
		echo "error: 'BITS_DIR' must be set for 'publish' target"; \
		exit 1; \
	fi
	mkdir -p $(BITS_DIR)/$(NAME)
	cp $(TOP)/$(RELEASE_TARBALL) $(BITS_DIR)/$(NAME)/$(RELEASE_TARBALL)

# Cherry-pick just the npm modules needed for the eslint check to speed up
# `make check` on the CI checker.
$(ESLINT): | $(NPM_EXEC)
	$(NPM) install \
	    eslint@`json -f package.json devDependencies.eslint` \
	    eslint-plugin-joyent@`json -f package.json devDependencies.eslint-plugin-joyent`

.PHONY: check-eslint
check-eslint: | $(ESLINT)
	$(ESLINT) -c $(ESLINT_CONF) $(ESLINT_FILES)

check:: check-eslint

include ./tools/mk/Makefile.deps
ifeq ($(shell uname -s),SunOS)
	include ./tools/mk/Makefile.node_prebuilt.targ
endif
include ./tools/mk/Makefile.smf.targ
include ./tools/mk/Makefile.targ
