#include <lua.hpp>
#include <string>
#include <string_view>
#include <memory>

static int lopen(lua_State *L)
{
    printf("lopen\n");
    return 2;
}

static int lsave(lua_State *L)
{
    printf("lsave\n");
    return 2;
}

extern "C" int luaopen_filedialog(lua_State *L)
{
    static luaL_Reg lib[] = {
        {"open", lopen},
        {"save", lsave},
        {NULL, NULL},
    };
    luaL_newlib(L, lib);
    return 1;
}
