/* nxvk_icd.c -- ICD entrypoint adapter for nxvk (PalindromicBreadLoaf/nxvk).
 *
 * nxvk exports exactly one symbol: vk_icdGetInstanceProcAddr. Everything the
 * port otherwise links directly (GIPA + the instance-level globals the core
 * resolves through our import table) is forwarded through it here, so the
 * Dantiicu-era direct-link assumptions keep working unchanged.
 *
 * Compiled only under -DUSE_VULKAN (make builds VK-only).
 */

#ifdef USE_VULKAN

#include <string.h>
#include <vulkan/vulkan_core.h>

extern PFN_vkVoidFunction VKAPI_CALL
vk_icdGetInstanceProcAddr(VkInstance instance, const char *pName);

PFN_vkVoidFunction VKAPI_CALL
vkGetInstanceProcAddr(VkInstance instance, const char *pName) {
  if (!pName)
    return NULL;
  if (!strcmp(pName, "vkGetInstanceProcAddr"))
    return (PFN_vkVoidFunction)vkGetInstanceProcAddr;
  return vk_icdGetInstanceProcAddr(instance, pName);
}

VkResult VKAPI_CALL
vkCreateInstance(const VkInstanceCreateInfo *pCreateInfo,
                 const VkAllocationCallbacks *pAllocator, VkInstance *pInstance) {
  PFN_vkCreateInstance fn = (PFN_vkCreateInstance)
      vk_icdGetInstanceProcAddr(NULL, "vkCreateInstance");
  if (!fn)
    return VK_ERROR_INITIALIZATION_FAILED;
  return fn(pCreateInfo, pAllocator, pInstance);
}

VkResult VKAPI_CALL
vkEnumerateInstanceVersion(uint32_t *pApiVersion) {
  PFN_vkEnumerateInstanceVersion fn = (PFN_vkEnumerateInstanceVersion)
      vk_icdGetInstanceProcAddr(NULL, "vkEnumerateInstanceVersion");
  if (!fn)
    return VK_ERROR_INITIALIZATION_FAILED;
  return fn(pApiVersion);
}

VkResult VKAPI_CALL
vkEnumerateInstanceLayerProperties(uint32_t *pPropertyCount,
                                   VkLayerProperties *pProperties) {
  PFN_vkEnumerateInstanceLayerProperties fn =
      (PFN_vkEnumerateInstanceLayerProperties)
          vk_icdGetInstanceProcAddr(NULL, "vkEnumerateInstanceLayerProperties");
  if (!fn)
    return VK_ERROR_INITIALIZATION_FAILED;
  return fn(pPropertyCount, pProperties);
}

void VKAPI_CALL
vkDestroyInstance(VkInstance instance, const VkAllocationCallbacks *pAllocator) {
  PFN_vkDestroyInstance fn = (PFN_vkDestroyInstance)
      vk_icdGetInstanceProcAddr(NULL, "vkDestroyInstance");
  if (fn)
    fn(instance, pAllocator);
}

#endif // USE_VULKAN
