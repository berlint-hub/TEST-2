/* egl_vk_stubs.c -- the few EGL/GLES symbols NVK does NOT already stub, for the
 * VULKAN build only.
 *
 * The Vulkan (NVK) build does NOT link switch-mesa's libEGL/libGLESv2 (they and
 * NVK both bundle mesa util/nir/compiler object code and can't co-link). But
 * libemucore.so has 19 undefined egl* dynamic imports and our EGL layer
 * (hooks/egl.c) still compiles and calls the raw egl and gl functions. NVK's own
 * rust_switch_stubs already provides most egl* symbols (eglGetDisplay,
 * eglSwapBuffers, ...); this file adds only the handful it does not, so the link
 * resolves. On the Vulkan renderer path the core drives GSDeviceVK and never
 * actually calls these -- they just need to exist and fail benignly. Compiled to
 * nothing in the OpenGL build (real switch-mesa symbols linked instead).
 */
#if defined(USE_VULKAN) && !defined(USE_UNIFIED_MESA)

#include <EGL/egl.h>
#include <GLES2/gl2.h>

EGLBoolean eglQuerySurface(EGLDisplay d, EGLSurface s, EGLint a, EGLint *v) {
  (void)d; (void)s; (void)a; if (v) *v = 0; return EGL_FALSE; }
EGLContext eglGetCurrentContext(void) { return EGL_NO_CONTEXT; }
EGLSurface eglGetCurrentSurface(EGLint rw) { (void)rw; return EGL_NO_SURFACE; }
const GLubyte *glGetString(GLenum name) { (void)name; return (const GLubyte *)""; }

/* nxvk provides no EGL at all (unlike the Dantiicu package, whose
 * rust_switch_stubs carried most egl* symbols). On the Vulkan renderer path
 * the core drives GSDeviceVK and never calls EGL -- our hooks/egl.c layer
 * still references the real entry points, so they must exist and fail
 * benignly for the link to resolve. */
EGLDisplay eglGetDisplay(EGLNativeDisplayType d) { (void)d; return EGL_NO_DISPLAY; }
EGLBoolean eglInitialize(EGLDisplay d, EGLint *ma, EGLint *mi) {
  (void)d; (void)ma; (void)mi; return EGL_FALSE; }
EGLBoolean eglBindAPI(EGLenum api) { (void)api; return EGL_FALSE; }
const char *eglQueryString(EGLDisplay d, EGLint n) { (void)d; (void)n; return NULL; }
EGLBoolean eglChooseConfig(EGLDisplay d, const EGLint *al, EGLConfig *c,
                           EGLint s, EGLint *n) {
  (void)d; (void)al; (void)c; (void)s; if (n) *n = 0; return EGL_FALSE; }
EGLBoolean eglGetConfigAttrib(EGLDisplay d, EGLConfig c, EGLint a, EGLint *v) {
  (void)d; (void)c; (void)a; if (v) *v = 0; return EGL_FALSE; }
EGLContext eglCreateContext(EGLDisplay d, EGLConfig c, EGLContext s,
                            const EGLint *a) {
  (void)d; (void)c; (void)s; (void)a; return EGL_NO_CONTEXT; }
EGLSurface eglCreateWindowSurface(EGLDisplay d, EGLConfig c,
                                  EGLNativeWindowType w, const EGLint *a) {
  (void)d; (void)c; (void)w; (void)a; return EGL_NO_SURFACE; }
EGLSurface eglCreatePbufferSurface(EGLDisplay d, EGLConfig c, const EGLint *a) {
  (void)d; (void)c; (void)a; return EGL_NO_SURFACE; }
EGLBoolean eglDestroySurface(EGLDisplay d, EGLSurface s) {
  (void)d; (void)s; return EGL_FALSE; }
EGLBoolean eglDestroyContext(EGLDisplay d, EGLContext c) {
  (void)d; (void)c; return EGL_FALSE; }
EGLBoolean eglMakeCurrent(EGLDisplay d, EGLSurface dr, EGLSurface r, EGLContext c) {
  (void)d; (void)dr; (void)r; (void)c; return EGL_FALSE; }
EGLBoolean eglSwapInterval(EGLDisplay d, EGLint i) { (void)d; (void)i; return EGL_FALSE; }
EGLBoolean eglSwapBuffers(EGLDisplay d, EGLSurface s) {
  (void)d; (void)s; return EGL_FALSE; }
void *eglGetProcAddress(const char *n) { (void)n; return NULL; }
EGLBoolean eglTerminate(EGLDisplay d) { (void)d; return EGL_FALSE; }
EGLBoolean eglReleaseThread(void) { return EGL_FALSE; }
EGLint eglGetError(void) { return EGL_SUCCESS; }

#endif // USE_VULKAN
