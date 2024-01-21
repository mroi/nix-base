# command line tool to switch display to 2560 x 1440 resolution for screen sharing with Jupiter
{ stdenv, darwin }:

stdenv.mkDerivation {
	name = "hires";
	buildInputs = with darwin.apple_sdk.frameworks; [ CoreGraphics ];
	unpackPhase = ''
		cat > hires.c <<- EOF
			#include <CoreGraphics/CoreGraphics.h>

			typedef struct {
				uint32_t id;
				uint32_t flags;
				uint32_t width;
				uint32_t height;
				uint32_t depth;
				uint8_t unknown[170];
				uint16_t freq;
				uint8_t more_unknown[16];
				float density;
			} CGSDisplayMode;

			extern void CGSGetNumberOfDisplayModes(CGDirectDisplayID display, CFIndex *nModes);
			extern void CGSGetDisplayModeDescriptionOfLength(CGDirectDisplayID display, CFIndex index, CGSDisplayMode *mode, int length);
			extern CGError CGSConfigureDisplayMode(CGDisplayConfigRef config, CGDirectDisplayID display, int id);


			int main(int argc, char *argv[])
			{
				uint32_t width, height;
				if (argc == 2 && argv[1][0] == 'o' && argv[1][1] == 'f' && argv[1][2] == 'f' && argv[1][3] == '\0') {
					width = 1440;
					height = 900;
				} else {
					width = 2560;
					height = 1440;
				}

				CFIndex index, count = 0;
				CGDisplayConfigRef config;

				CGBeginDisplayConfiguration(&config);

				CGDirectDisplayID display = CGMainDisplayID();
				CGSGetNumberOfDisplayModes(display, &count);

				CGSDisplayMode mode;
				for (index = 0; index < count; index++) {
					CGSGetDisplayModeDescriptionOfLength(display, index, &mode, sizeof(mode));
					if (mode.width == width && mode.height == height) break;
				}
				if (index == count) abort();

				CGSConfigureDisplayMode(config, display, mode.id);

				CGCompleteDisplayConfiguration(config, kCGConfigurePermanently);
			}
		EOF
	'';
	buildPhase = ''
		cc -O2 -framework CoreGraphics -framework CoreFoundation -o hires hires.c
	'';
	installPhase = ''
		mkdir -p $out/bin
		cp hires $out/bin/
	'';
}
