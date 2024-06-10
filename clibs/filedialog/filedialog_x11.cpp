#include <lua.hpp>
#include <string>
#include <string_view>
#include <memory>

static void dlg_set_title(lua_State *L, int idx)
{
    if (LUA_TSTRING == lua_getfield(L, idx, "Title"))
    {
        size_t len = 0;
        const char *title = luaL_checklstring(L, -1, &len);
        printf("Title:%s\n", title);
    }
    lua_pop(L, 1);
}

static int lcreate(lua_State *L, bool is_open_only)
{ 
    luaL_checktype(L, 1, LUA_TTABLE);
    
    dlg_set_title(L, 1);

    int file_result = 0;
    const char* file_path = "";

    lua_pushboolean(L, file_result);
    lua_pushstring(L, file_path);
    return 2;
}

static int lopen(lua_State *L)
{
    return lcreate(L, true);
}

static int lsave(lua_State *L)
{
    return lcreate(L, false);
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
