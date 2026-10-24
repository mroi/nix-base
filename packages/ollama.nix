# ollama with MLX backend, patched for launchd integration and defaulting to no chat history
{ lib, stdenvNoCC, ollama, apple-sdk_26, cacert, zsh, writeScriptBin, writeText, mlxBackend ? false }:

assert mlxBackend -> stdenvNoCC.hostPlatform.isDarwin;

let

	# expose platform xcrun and resolve the metal tool manually, otherwise xcrun resolves metal to
	# a stub, because the build user’s xcrun_db has no metal download registered
	xcrun = writeScriptBin "xcrun" ''#!/bin/sh
		unset DEVELOPER_DIR SDKROOT
		metal=$(ls -d /private/var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-*/Metal.xctoolchain/usr/bin/metal 2>/dev/null | head -1)
		if ! test "$metal" ; then
			echo 'Metal toolchain not found' ; exit 1
		fi
		case " $* " in
			*' -f metal '*) echo "$metal" ; exit 0 ;;
		esac
		case "$1 $3" in
			'-sdk metal') shift 3 ; exec "$metal" "$@" ;;
			'metal '*) shift ; exec "$metal" "$@" ;;
		esac
		exec /usr/bin/xcrun "$@"
	'';

	# MLX build requires sw_vers
	sw_vers = writeScriptBin "sw_vers" ''#!/bin/sh
		echo '${apple-sdk_26.version}'
	'';

in ollama.overrideAttrs (attrs: {

	patches = attrs.patches or [] ++ lib.optional stdenvNoCC.hostPlatform.isDarwin (writeText "launchd-integration.patch" ''
		--- a/cmd/cmd.go
		+++ b/cmd/cmd.go
		@@ -28,6 +28,7 @@
		 	"sync/atomic"
		 	"syscall"
		 	"time"
		+	"unsafe"
		 
		 	"github.com/containerd/console"
		 	"github.com/mattn/go-runewidth"
		@@ -58,6 +59,12 @@
		 	"github.com/ollama/ollama/types/syncmap"
		 	"github.com/ollama/ollama/version"
		 )
		+
		+/*
		+#include <stdlib.h>
		+int launch_activate_socket(const char *name, int **fds, size_t *cnt);
		+*/
		+import "C"
		 
		 func init() {
		 	// Override default selectors to use Bubbletea TUI instead of raw terminal I/O.
		@@ -2220,12 +2227,18 @@
		 	return nil
		 }
		 
		-func RunServer(_ *cobra.Command, _ []string) error {
		+func RunServer(cmd *cobra.Command, _ []string) error {
		 	if err := initializeKeypair(); err != nil {
		 		return err
		 	}
		 
		-	ln, err := net.Listen("tcp", envconfig.Host().Host)
		+	ln, err := func() (net.Listener, error) {
		+		if launchd, _ := cmd.Flags().GetBool("launchd"); launchd {
		+			return getLaunchdSocket("ollama")
		+		} else {
		+			return net.Listen("tcp", envconfig.Host().Host)
		+		}
		+	}()
		 	if err != nil {
		 		return err
		 	}
		@@ -2282,6 +2295,27 @@
		 		fmt.Printf("Your new public key is: \n\n%s\n", publicKeyBytes)
		 	}
		 	return nil
		+}
		+
		+func getLaunchdSocket(name string) (net.Listener, error) {
		+	cName := C.CString(name)
		+	var fds *C.int
		+	len := C.size_t(0)
		+
		+	err := C.launch_activate_socket(cName, &fds, &len)
		+	if err != 0 {
		+		return nil, errors.New("could not obtain socket ‘" + name + "’ from launchd")
		+	}
		+
		+	if len != 1 {
		+		return nil, errors.New("obtained an unexpected number of file descriptros from launchd")
		+	}
		+
		+	fd := uintptr(*fds)
		+	C.free(unsafe.Pointer(fds))
		+
		+	file := os.NewFile(fd, "")
		+	return net.FileListener(file)
		 }
		 
		 func checkServerHeartbeat(cmd *cobra.Command, _ []string) error {
		@@ -2609,6 +2643,8 @@
		 		RunE:    RunServer,
		 	}
		 
		+	serveCmd.Flags().Bool("launchd", false, "Pass file descriptor from launchd")
		+
		 	pullCmd := &cobra.Command{
		 		Use:     "pull MODEL",
		 		Short:   "Pull a model from a registry",
	'') ++ lib.singleton (writeText "default-no-history.patch" ''
		--- a/envconfig/config.go
		+++ b/envconfig/config.go
		@@ -221,7 +221,7 @@
		 	// KvCacheType is the quantization type for the K/V cache.
		 	KvCacheType = String("OLLAMA_KV_CACHE_TYPE")
		 	// NoHistory disables readline history.
		-	NoHistory = Bool("OLLAMA_NOHISTORY")
		+	NoHistory = func() bool { return true }
		 	// NoPrune disables pruning of model blobs on startup.
		 	NoPrune = Bool("OLLAMA_NOPRUNE")
		 	// SchedSpread allows scheduling models across all GPUs.
		--- a/readline/history.go
		+++ b/readline/history.go
		@@ -44,13 +44,9 @@
		 	}
		 
		 	path := filepath.Join(home, ".ollama", "history")
		-	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		-		return err
		-	}
		-
		 	h.Filename = path
		 
		-	f, err := os.OpenFile(path, os.O_CREATE|os.O_RDONLY, 0o600)
		+	f, err := os.OpenFile(path, os.O_RDONLY, 0o600)
		 	if err != nil {
		 		if errors.Is(err, os.ErrNotExist) {
		 			return nil
		@@ -127,6 +123,10 @@
		 		return nil
		 	}
		 
		+	if err := os.MkdirAll(filepath.Dir(h.Filename), 0o755); err != nil {
		+		return err
		+	}
		+
		 	tmpFile := h.Filename + ".tmp"
		 
		 	f, err := os.OpenFile(tmpFile, os.O_CREATE|os.O_WRONLY|os.O_TRUNC|os.O_APPEND, 0o600)
	'');

} // lib.optionalAttrs mlxBackend {

	# build with MLX backend on Darwin
	__noChroot = true;
	cmakeFlags = attrs.cmakeFlags or [] ++ [ "-DOLLAMA_MLX_BACKENDS=metal_v4" ];
	buildInputs = attrs.buildInputs ++ [ apple-sdk_26 ];
	nativeBuildInputs = attrs.nativeBuildInputs ++ [ xcrun zsh cacert sw_vers ];
	postPatch = attrs.postPatch + ''
		# disable tests that fail in the Nix sandbox
		rm mlx/mlxthread/*_test.go
		rm mlxrunner/model/glm4_moe_lite/*_test.go
	'';
})
