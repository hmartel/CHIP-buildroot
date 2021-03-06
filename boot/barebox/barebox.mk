################################################################################
#
# barebox
#
################################################################################

BAREBOX_VERSION = $(call qstrip,$(BR2_TARGET_BAREBOX_VERSION))

ifeq ($(BAREBOX_VERSION),custom)
# Handle custom Barebox tarballs as specified by the configuration
BAREBOX_TARBALL = $(call qstrip,$(BR2_TARGET_BAREBOX_CUSTOM_TARBALL_LOCATION))
BAREBOX_SITE = $(patsubst %/,%,$(dir $(BAREBOX_TARBALL)))
BAREBOX_SOURCE = $(notdir $(BAREBOX_TARBALL))
BR_NO_CHECK_HASH_FOR += $(BAREBOX_SOURCE)
else ifeq ($(BR2_TARGET_BAREBOX_CUSTOM_GIT),y)
BAREBOX_SITE = $(call qstrip,$(BR2_TARGET_BAREBOX_CUSTOM_GIT_REPO_URL))
BAREBOX_SITE_METHOD = git
else
# Handle stable official Barebox versions
BAREBOX_SOURCE = barebox-$(BAREBOX_VERSION).tar.bz2
BAREBOX_SITE = http://www.barebox.org/download
ifeq ($(BR2_TARGET_BAREBOX_CUSTOM_VERSION),y)
BR_NO_CHECK_HASH_FOR += $(BAREBOX_SOURCE)
endif
endif

BAREBOX_DEPENDENCIES = host-lzop
BAREBOX_LICENSE = GPLv2 with exceptions
BAREBOX_LICENSE_FILES = COPYING

ifneq ($(call qstrip,$(BR2_TARGET_BAREBOX_CUSTOM_PATCH_DIR)),)
define BAREBOX_APPLY_CUSTOM_PATCHES
	$(APPLY_PATCHES) $(@D) \
		$(BR2_TARGET_BAREBOX_CUSTOM_PATCH_DIR) \*.patch
endef

BAREBOX_POST_PATCH_HOOKS += BAREBOX_APPLY_CUSTOM_PATCHES
endif

BAREBOX_INSTALL_IMAGES = YES
ifneq ($(BR2_TARGET_BAREBOX_BAREBOXENV),y)
BAREBOX_INSTALL_TARGET = NO
endif

ifeq ($(KERNEL_ARCH),i386)
BAREBOX_ARCH = x86
else ifeq ($(KERNEL_ARCH),x86_64)
BAREBOX_ARCH = x86
else ifeq ($(KERNEL_ARCH),powerpc)
BAREBOX_ARCH = ppc
else
BAREBOX_ARCH = $(KERNEL_ARCH)
endif

BAREBOX_MAKE_FLAGS = ARCH=$(BAREBOX_ARCH) CROSS_COMPILE="$(CCACHE) \
	$(TARGET_CROSS)"
BAREBOX_MAKE_ENV = $(TARGET_MAKE_ENV)

ifeq ($(BR2_TARGET_BAREBOX_USE_DEFCONFIG),y)
BAREBOX_SOURCE_CONFIG = $(BAREBOX_DIR)/arch/$(BAREBOX_ARCH)/configs/$(call qstrip,\
	$(BR2_TARGET_BAREBOX_BOARD_DEFCONFIG))_defconfig
else ifeq ($(BR2_TARGET_BAREBOX_USE_CUSTOM_CONFIG),y)
BAREBOX_SOURCE_CONFIG = $(call qstrip,$(BR2_TARGET_BAREBOX_CUSTOM_CONFIG_FILE))
endif

BAREBOX_KCONFIG_FILE = $(BAREBOX_SOURCE_CONFIG)
BAREBOX_KCONFIG_FRAGMENT_FILES = $(call qstrip,$(BR2_TARGET_BAREBOX_CONFIG_FRAGMENT_FILES))
BAREBOX_KCONFIG_EDITORS = menuconfig xconfig gconfig nconfig
BAREBOX_KCONFIG_OPTS = $(BAREBOX_MAKE_FLAGS)

ifeq ($(BR2_TARGET_BAREBOX_BAREBOXENV),y)
define BAREBOX_BUILD_BAREBOXENV_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) -o $(@D)/bareboxenv \
		$(@D)/scripts/bareboxenv.c
endef
endif

ifeq ($(BR2_TARGET_BAREBOX_CUSTOM_ENV),y)
BAREBOX_ENV_NAME = $(notdir $(call qstrip,\
	$(BR2_TARGET_BAREBOX_CUSTOM_ENV_PATH)))
define BAREBOX_BUILD_CUSTOM_ENV
	$(@D)/scripts/bareboxenv -s \
		$(call qstrip, $(BR2_TARGET_BAREBOX_CUSTOM_ENV_PATH)) \
		$(@D)/$(BAREBOX_ENV_NAME)
endef
define BAREBOX_INSTALL_CUSTOM_ENV
	cp $(@D)/$(BAREBOX_ENV_NAME) $(BINARIES_DIR)
endef
endif

define BAREBOX_BUILD_CMDS
	$(BAREBOX_BUILD_BAREBOXENV_CMDS)
	$(TARGET_MAKE_ENV) $(MAKE) $(BAREBOX_MAKE_FLAGS) -C $(@D)
	$(BAREBOX_BUILD_CUSTOM_ENV)
endef

define BAREBOX_INSTALL_IMAGES_CMDS
	if test -h $(@D)/barebox-flash-image ; then \
		cp -L $(@D)/barebox-flash-image $(BINARIES_DIR)/barebox.bin ; \
	else \
		cp $(@D)/barebox.bin $(BINARIES_DIR);\
	fi
	$(BAREBOX_INSTALL_CUSTOM_ENV)
endef

ifeq ($(BR2_TARGET_BAREBOX_BAREBOXENV),y)
define BAREBOX_INSTALL_TARGET_CMDS
	cp $(@D)/bareboxenv $(TARGET_DIR)/usr/bin
endef
endif

# Checks to give errors that the user can understand
# Must be before we call to kconfig-package
ifeq ($(BR2_TARGET_BAREBOX)$(BR_BUILDING),yy)
ifeq ($(BAREBOX_SOURCE_CONFIG),)
$(error No Barebox config file. Check your BR2_TARGET_BAREBOX_BOARD_DEFCONFIG or BR2_TARGET_BAREBOX_CUSTOM_CONFIG_FILE settings)
endif
endif

$(eval $(kconfig-package))
