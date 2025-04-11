ObjC.import("Security")

// JavaScript for automation (JXA) does not recognize CF types dynamically at runtime
// unrecognized types passed to CF function arguments get wrapped in a CFDictionary
// declaring function arguments to be "void *" prevents this unwanted wrapping
ObjC.bindFunction("CFDictionaryGetValue", ["void *", ["void *", "void *"]])
ObjC.bindFunction("CFBooleanGetValue", ["bool", ["void *"]])

const auth = Ref()
const status = $.AuthorizationRightGet("system.preferences", auth)

if (status == $.errAuthorizationSuccess) {
	const sharedKey = $.CFStringCreateWithCString(null, "shared", $.kCFStringEncodingASCII)
	const sharedValue = $.CFDictionaryGetValue(auth[0], sharedKey)
	$.CFBooleanGetValue(sharedValue)
}
