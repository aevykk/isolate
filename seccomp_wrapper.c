#include <stdio.h>
#include <stdlib.h>
#include <linux/seccomp.h>
#include <seccomp.h>
#include <sys/prctl.h>
#include <sys/syscall.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <sys/mount.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
	fprintf(stderr, "--> SECCOMP WRAPPER ACTIVE <--\n");

	if (argc < 2) {
		fprintf(stderr, "usage: %s command [args]...\n", argv[0]);
		return 1;
	}

	scmp_filter_ctx ctx = seccomp_init(SCMP_ACT_ALLOW);

	// also filter the compat ABIs so a 32-bit binary cannot bypass the filter.
	// EEXIST for the native arch is expected and ignored.
	seccomp_arch_add(ctx, SCMP_ARCH_X86);
	seccomp_arch_add(ctx, SCMP_ARCH_X32);

	// block terminal-injection ioctls that could push input to the host tty
	const int injection_ioctls[] = { TIOCSTI, TIOCLINUX };
	for (unsigned i = 0; i < sizeof(injection_ioctls) / sizeof(injection_ioctls[0]); i++) {
		if (seccomp_rule_add(ctx, SCMP_ACT_KILL_PROCESS, SCMP_SYS(ioctl), 1,
							 SCMP_A1(SCMP_CMP_EQ, injection_ioctls[i], injection_ioctls[i]))) {
			if (ctx) seccomp_release(ctx);
			fprintf(stderr, "[1471] failed to install seccomp filter\n");
			return 1;
		}
	}
	if(seccomp_load(ctx)){
		fprintf(stderr, "[1472] failed to load seccomp context\n");
		return 1;
	}

	char **args = (char**) malloc(sizeof(char*) * argc);
	int i = 0;
	for (i = 0; i < argc - 1; i++){
		args[i] = argv[i+1];
	}
	args[i] = NULL;
    return execvp(args[0], args);
}
