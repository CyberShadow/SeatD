#include <iostream>
#include <dlfcn.h>

typedef void* (*getSEATDInstance_t)(void*);

int main(int argc, char** argv)
{
    using std::cout;
    using std::cerr;

    // open the library
    cout << "Opening " << argv[1] << "...\n";
    void* handle = dlopen(argv[1], RTLD_LAZY);
    
    if ( !handle ) {
        cerr << "Cannot open library: " << dlerror() << '\n';
        return 1;
    }
    
    // load the symbol
    cout << "Loading symbol...\n";

    // reset errors
    const char* err = dlerror();
    if ( err )
        cerr << "Errors: " << dlerror() << '\n';
    getSEATDInstance_t getSEATDInstance = (getSEATDInstance_t)dlsym(handle, "getSEATDInstance");
    const char *dlsym_error = dlerror();
    if ( dlsym_error ) {
        cerr << "Cannot load symbol 'getSEATDInstance': " << dlsym_error << '\n';
        dlclose(handle);
        return 1;
    }
    
    // use it to do the calculation
    cout << "Creating D instance...\n";
    char str[80];
    memcpy(str, "from C++ to D", 14);
    printf("sending pointer %x\n", str);
    void* instance = getSEATDInstance(str);
    printf("recieved pointer %x\n", instance);
    
    // close the library
    cout << "Closing library...\n";
    dlclose(handle);
}
