# ollama patched for launchd integration and defaulting to no chat history
{ lib, stdenv, ollama, writeText }:

ollama.overrideAttrs (attrs: {
	patches = attrs.patches or [] ++ lib.optional stdenv.isDarwin (writeText "launchd-integration.patch" ''
		--- a/cmd/cmd.go
		+++ b/cmd/cmd.go
		@@ -25,6 +25,7 @@
		 	"sync/atomic"
		 	"syscall"
		 	"time"
		+	"unsafe"
		 
		 	"github.com/containerd/console"
		 	"github.com/mattn/go-runewidth"
		@@ -50,6 +51,12 @@
		 	imagegenclient "github.com/ollama/ollama/x/imagegen/client"
		 )
		 
		+/*
		+#include <stdlib.h>
		+int launch_activate_socket(const char *name, int **fds, size_t *cnt);
		+*/
		+import "C"
		+
		 const ConnectInstructions = "To sign in, navigate to:\n    %s\n\n"
		 
		 // ensureThinkingSupport emits a warning if the model does not advertise thinking support
		@@ -1598,12 +1605,18 @@
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
		@@ -1662,6 +1675,27 @@
		 	return nil
		 }
		 
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
		+}
		+
		 func checkServerHeartbeat(cmd *cobra.Command, _ []string) error {
		 	client, err := api.ClientFromEnvironment()
		 	if err != nil {
		@@ -1807,6 +1841,8 @@
		 		Args:    cobra.ExactArgs(0),
		 		RunE:    RunServer,
		 	}
		+
		+	serveCmd.Flags().Bool("launchd", false, "Pass file descriptor from launchd")
		 
		 	pullCmd := &cobra.Command{
		 		Use:     "pull MODEL",
	'') ++ lib.singleton (writeText "default-no-history.patch" ''
		--- a/envconfig/config.go
		+++ b/envconfig/config.go
		@@ -191,7 +191,7 @@
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
})
