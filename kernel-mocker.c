#include <string.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdbool.h>
#include <limits.h>

#define gfp_t unsigned int


void __dynamic_pr_debug(void *struct_ddebug_descriptor, const char *fmt, ...) {}

/* Locking functions, ignore as we are single-threaded */
void down_write(void *struct_rw_semaphore_sem) {}
void down_read(void *struct_rw_semaphore_sem) {}
void up_read(void *struct_rw_semaphore_sem) {}
void up_write(void *struct_rw_semaphore_sem) {}


int __request_module (bool wait, const char * fmt, ...) {
	return 0;
}

long wait_for_completion_killable_timeout(void *struct_completion_x, unsigned long timeout)
{
	return 1;
}

/* Assume module we are using is loaded */
bool try_module_get(void *struct_module_module) {
	return 1;
}
void __module_get(void *struct_module_module) {}
void module_put(void *module) {
	return;
}



/* Memory allocation functions */
void *kmalloc_node(size_t size, gfp_t flags, int node) {
	return malloc(size);
}
void* kzalloc(size_t size,gfp_t flags) {
	return calloc(1, size);
}

void* kmalloc_caches[128][128];

void *kmemdup (const void * src, size_t len, gfp_t gfp) {
	void *ret = malloc(len);
	memcpy(ret, src, len);
	return ret;
		
}
void *kmalloc_trace(void *struct_kmem_cache_s, gfp_t flags, size_t size) {
	return malloc(size);
}

void kfree_sensitive(void *x) {
	free(x);
}
				    
void kfree(void *x) {
	free(x);
}

void * __kmalloc (size_t size, int flags) {
	return malloc(size);
}


/* Output and crash functions */
void check_panic_on_warn(const char *origin) {}
void __ubsan_handle_out_of_bounds(void *_data, void *index) {}
void panic(const char *fmt, ...) {
	exit(1);
}
int _printk(const char *s, ...)
{
	// TODO, actually print stuff
	return 0;
}

/* String functions */
#define	E2BIG		 7
ssize_t strscpy(char *dest, const char *src, size_t count)
{
	long res = 0;

	if (count == 0 || count > INT_MAX)
		return -E2BIG;

	while (count) {
		char c;

		c = src[res];
		dest[res] = c;
		if (!c)
			return res;
		res++;
		count--;
	}

	/* Hit buffer length without finding a NUL; force NUL-termination. */
	if (res)
		dest[res-1] = '\0';

	return -E2BIG;
}


size_t strlcpy(char *dest, const char *src, size_t size)
{
	size_t ret = strlen(src);

	if (size) {
		size_t len = (ret >= size) ? size - 1 : ret;
		memcpy(dest, src, len);
		dest[len] = '\0';
	}
	return ret;
}
