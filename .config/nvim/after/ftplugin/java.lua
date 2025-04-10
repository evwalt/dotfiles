local config = {
	cmd = { "jdtls" },
	root_dir = require("jdtls.setup").find_root({ ".git", "mvnw", "gradlew" }),
}
require("jdtls").start_or_attach(config)
