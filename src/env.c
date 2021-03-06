#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include <stdlib.h>
#include <string.h>
#include <ctype.h>

/*
ENV_PUTENV_HAS_UNDERLINE                     _putenv

ENV_SET_BY_PUTENV                            putenv("KEY=value")
ENV_SET_BY_SETENV                            setenv("KEY", "value", 1)

ENV_UNSET_BY_PUTENV                          putenv("KEY")
ENV_UNSET_BY_PUTENV_EQ                       putenv("KEY=")
ENV_UNSET_BY_UNSETENV                        unsetenv("KEY")
ENV_UNSET_BY_SETENV                          setenv("KEY", "", 1)
ENV_UNSET_BY_SETENV_NULL                     setenv("KEY", NULL, 1)
*/
#ifdef _MSC_VER 
#  define ENV_PUTENV_HAS_UNDERLINE 1
#  define ENV_SET_BY_PUTENV 1
#  define ENV_UNSET_BY_PUTENV_EQ 1
#elif _BSD_SOURCE || _POSIX_C_SOURCE >= 200112L || _XOPEN_SOURCE >= 600 
#  define ENV_SET_BY_SETENV 1
#  define ENV_UNSET_BY_UNSETENV 1
#endif

static int str_upper (lua_State *L, int idx){
  size_t l,i;
  luaL_Buffer b;
  const char *s = luaL_checklstring(L, idx, &l);
  for (i = 0; i < l; i++){
    if(islower(s[i]))
      break;
  }  
  if(i == l)
    return 1;

  luaL_buffinit(L, &b);
  for (i = 0; i < l; i++)
    luaL_addchar(&b, toupper((unsigned char)(s[i])));
  luaL_pushresult(&b);
  lua_remove(L, (idx > 0)?idx:idx-1);
  lua_insert(L,idx);
  return 1;
}

#ifdef ENV_EXPORT_WIN
#include <windows.h>
#include <strsafe.h>

void push_lasterr(lua_State *L, LPTSTR lpszFunction) { 
  LPVOID lpMsgBuf;
  LPVOID lpDisplayBuf;
  DWORD dw = GetLastError(); 

  FormatMessage(
    FORMAT_MESSAGE_ALLOCATE_BUFFER | 
    FORMAT_MESSAGE_FROM_SYSTEM,
    NULL,
    dw,
    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
    (LPTSTR) &lpMsgBuf,
    0, NULL );

  lpDisplayBuf = (LPVOID)LocalAlloc(LMEM_ZEROINIT, 
    (lstrlen((LPCTSTR)lpMsgBuf)+lstrlen((LPCTSTR)lpszFunction)+40)*sizeof(TCHAR)); 
  StringCchPrintf((LPTSTR)lpDisplayBuf, 
    LocalSize(lpDisplayBuf),
    TEXT("%s failed with error %d: %s"), 
    lpszFunction, dw, lpMsgBuf);
  
  lua_pushstring(L,(LPTSTR)lpDisplayBuf);
  LocalFree(lpMsgBuf);
  LocalFree(lpDisplayBuf);
}

static int l_expenv_win(lua_State *L){
#define INFO_BUFFER_SIZE 1024
  static char infoBuf[INFO_BUFFER_SIZE];
  const char * envVar = luaL_checkstring(L,1);
  DWORD  bufCharCount = INFO_BUFFER_SIZE;
  luaL_checktype(L, 2, LUA_TNONE);

  if(!*envVar){
    lua_pushstring(L,"");
    return 1;
  }

  bufCharCount = ExpandEnvironmentStrings(envVar, infoBuf, INFO_BUFFER_SIZE);
  if( !bufCharCount ){
    lua_pushnil(L);
    push_lasterr(L,"\"expenv\"");
    return 2;
  }

  if( bufCharCount <= INFO_BUFFER_SIZE ){
    lua_pushstring(L, infoBuf);
    return 1;
  }

  {
    DWORD newBufSize = bufCharCount + 1;
    char *buf = malloc( newBufSize );

    if (!buf){
      lua_pushnil(L);
      push_lasterr(L,"\"expenv\"(alloc memory)");
      return 2;
    }

    bufCharCount = ExpandEnvironmentStrings(envVar, buf, newBufSize);
    if( !bufCharCount ){
      free(buf);
      lua_pushnil(L);
      push_lasterr(L,"\"expenv\"");
      return 2;
    }

    if( bufCharCount > newBufSize ){
      free(buf);
      lua_pushnil(L);
      lua_pushstring(L,"\"expenv: can not alloc enough memoty\"");
      return 2;
    }

    lua_pushstring(L, buf);
    free(buf);
    return 1;
  }

#undef INFO_BUFFER_SIZE
}

static int l_getenviron_win(lua_State *L){
  int as_map = lua_toboolean(L,1);
  LPSTR lpszVariable; 
  LPVOID lpvEnv; 
  int i = 0;
  luaL_checktype(L, 2, LUA_TNONE);

  lpvEnv = GetEnvironmentStrings();
  if (lpvEnv == NULL){
    lua_pushnil(L);
    push_lasterr(L, "getenviron failed:");
    return 2;
  }

  lua_newtable(L);
  if(as_map) for (lpszVariable = (LPTSTR) lpvEnv; *lpszVariable; lpszVariable++){
    size_t len=lstrlen(lpszVariable);
    const char *eq = strchr( ('=' == lpszVariable[0])?&lpszVariable[1]:&lpszVariable[0], '=' );
    if(!eq){
      lua_pushstring(L, lpszVariable);
      lua_rawseti(L,-2,++i);
    }
    else{
      lua_pushlstring( L, lpszVariable, eq-lpszVariable );
      str_upper(L, -1);
      lua_pushstring(L, &eq[1]);
      lua_rawset(L, -3);
    }
    lpszVariable += len;
  }
  else for (lpszVariable = (LPTSTR) lpvEnv; *lpszVariable; lpszVariable++){
    size_t len=lstrlen(lpszVariable);
    lua_pushstring(L, lpszVariable);
    lua_rawseti(L,-2,++i);
    lpszVariable += len;
  }

  FreeEnvironmentStrings(lpvEnv);
  return 1;
}

static int l_getenv_win(lua_State *L){
#define INFO_BUFFER_SIZE 1024

  static char infoBuf[INFO_BUFFER_SIZE];
  const char * envVar = luaL_checkstring(L,1);
  DWORD  bufCharCount = INFO_BUFFER_SIZE;
  luaL_checktype(L, 2, LUA_TNONE);

  SetLastError(ERROR_SUCCESS);
  bufCharCount = GetEnvironmentVariable(envVar, infoBuf, INFO_BUFFER_SIZE);

  if( !bufCharCount ){
    DWORD err = GetLastError();
    if(ERROR_SUCCESS == err){ // empty string
      lua_pushliteral(L, "");
      return 1;
    }

    lua_pushnil(L);
    if (ERROR_ENVVAR_NOT_FOUND == err)
      return 1;

    push_lasterr(L,"\"getenv\"");
    return 2;
  }

  if( bufCharCount <= INFO_BUFFER_SIZE ){
    lua_pushstring(L, infoBuf);
    return 1;
  }

  {
    DWORD newBufSize = bufCharCount + 1;
    char *buf = malloc( newBufSize );

    if (!buf){
      lua_pushnil(L);
      push_lasterr(L,"\"getenv\"(alloc memory)");
      return 2;
    }

    bufCharCount = GetEnvironmentVariable(envVar, buf, newBufSize);
    if( !bufCharCount ){
      free(buf);
      lua_pushnil(L);
      if (ERROR_ENVVAR_NOT_FOUND == GetLastError())
        return 1;
      push_lasterr(L,"\"expenv\"");
      return 2;
    }

    if( bufCharCount > newBufSize ){
      free(buf);
      lua_pushnil(L);
      lua_pushstring(L,"\"expenv: can not alloc enough memoty\"");
      return 2;
    }

    lua_pushstring(L, buf);
    free(buf);
    return 1;
  }

#undef INFO_BUFFER_SIZE
}

static int call_win_setenv(lua_State *L, const char * envKey, const char * envVar){
  BOOL ret = SetEnvironmentVariable(envKey, envVar);
  if (!ret){
    lua_pushnil(L);
    push_lasterr(L,"\"setenv\"");
    return 2;
  }
  lua_pushboolean(L,1);
  return 1;
}

static int l_setenv_win(lua_State *L){
  const char *envKey = luaL_checkstring(L,1);
  luaL_checktype(L, 3, LUA_TNONE);

  if(lua_isnil(L,2) || lua_isnone(L,2))// unset
    return call_win_setenv(L, envKey, NULL);
  return call_win_setenv(L, envKey, luaL_checkstring(L,2));
}

static int l_update_win(lua_State *L){
  DWORD dwReturnValue;
  LRESULT ret = SendMessageTimeout(HWND_BROADCAST, WM_SETTINGCHANGE, 0,
    (LPARAM) "Environment", SMTO_ABORTIFHUNG,
    5000, &dwReturnValue
  );
  if(ret){
    lua_pushnumber(L,dwReturnValue);
    return 1;
  }

  lua_pushnil(L);
  push_lasterr(L,"\"updateenv\"");
  return 2;
}

#endif // ENV_EXPORT_WIN

#if _MSC_VER >= 1400
static int l_getenv_s(lua_State *L){
#define INFO_BUFFER_SIZE 1024

  static char infoBuf[INFO_BUFFER_SIZE];
  const char *key = luaL_checkstring(L,-1);
  size_t requiredSize = 0;
  errno_t ret = 0;
  char* value = NULL;

  ret = getenv_s( &requiredSize, infoBuf, INFO_BUFFER_SIZE-1, key );
  if(ret){
    lua_pushnil(L);
    lua_pushstring(L,"\"getenv: error while call getenv\"");
    lua_pushnumber(L,ret);
    return 3;
  }
  if(requiredSize < INFO_BUFFER_SIZE-1){
    if (*infoBuf)
      lua_pushstring(L, infoBuf);
    else
      lua_pushnil(L);
    return 1;
  }

  value = (char*) malloc(requiredSize * sizeof(char) + 1);
  if (!value){
    lua_pushnil(L);
    lua_pushstring(L,"\"getenv: can not alloc enough memoty\"");
    return 2;
  }

  ret = getenv_s( &requiredSize, value, requiredSize, key );
  if(ret){
    free(value);
    lua_pushnil(L);
    lua_pushstring(L,"\"getenv: error while call getenv\"");
    lua_pushnumber(L,ret);
    return 3;
  }

  if (*value)
    lua_pushstring(L, value);
  else
    lua_pushnil(L);

  free(value);
  return 1;

#undef INFO_BUFFER_SIZE
}
#endif //! _MSC_VER

//------------------------------------------
// implementation of setenv
//{-----------------------------------------

#if defined(ENV_UNSET_BY_PUTENV_EQ) && !defined(ENV_UNSET_BY_PUTENV)
#  define ENV_UNSET_BY_PUTENV 1
#endif

#if defined(ENV_UNSET_BY_SETENV_NULL) && !defined(ENV_UNSET_BY_SETENV)
#  define ENV_UNSET_BY_SETENV 1
#endif

#if defined(ENV_SET_BY_PUTENV) || defined(ENV_UNSET_BY_PUTENV)
#  define ENV_USE_PUTENV 1
#endif

#ifdef ENV_USE_PUTENV
#  ifdef ENV_PUTENV_HAS_UNDERLINE
#    define ENV_PUTENV _putenv
#  else
#    define ENV_PUTENV putenv
#  endif
#endif

#ifndef ENV_PUTENV_IS_ERROR
#  define ENV_PUTENV_IS_ERROR(V) ((V) != 0)
#endif

#ifndef ENV_SETENV_IS_ERROR
#define ENV_SETENV_IS_ERROR(V) ((V) != 0)
#endif

#ifdef ENV_USE_PUTENV
static int env_call_putenv(lua_State *L){
  int ret = ENV_PUTENV(lua_tostring(L,-1));
  if(ENV_PUTENV_IS_ERROR(ret)){
    lua_pushnil(L);
    lua_pushnumber(L, ret);
    return 2;
  }
  lua_pushboolean(L,1);
  return 1;
}
#endif

static int env_setenv(lua_State *L){
  const char * envKey = luaL_checkstring(L,1);
  const char * envVar = (lua_isnil(L,2) || lua_isnone(L,2)) ? NULL : luaL_checkstring(L,2);
  luaL_checktype(L, 3, LUA_TNONE);
  
  if(envVar){ // set
#ifdef ENV_SET_BY_PUTENV
    lua_pushliteral(L, "=");
    lua_insert(L, -2);
    lua_concat(L,3);
    return env_call_putenv(L);
#elif defined(ENV_SET_BY_SETENV)
    int ret = setenv(envKey, envVar, 1);
    if (ENV_SETENV_IS_ERROR(ret)) {
      lua_pushnil(L);
      lua_pushnumber(L, ret);
      return 2;
    }
    lua_pushboolean(L,1);
    return 1;
#else
#  error "Do not how set environment variable!"
#endif
  }
  if(lua_gettop(L) == 2)
    lua_pop(L,1); // remove nil
  
#ifdef ENV_UNSET_BY_PUTENV
# ifdef ENV_UNSET_BY_PUTENV_EQ
  lua_pushliteral(L, "=");
  lua_concat(L,2);
#  endif
  return env_call_putenv(L);
#elif defined(ENV_UNSET_BY_UNSETENV)
  int ret = unsetenv(envKey);
  if (ENV_SETENV_IS_ERROR(ret)) {
    lua_pushnil(L);
    lua_pushnumber(L, ret);
    return 2;
  }
  lua_pushboolean(L,1);
  return 1;
#elif defined(ENV_UNSET_BY_SETENV)
  int ret = setenv(envKey, 
#ifdef ENV_UNSET_BY_SETENV_NULL
    NULL
#else
    ""
#endif
  ,1);
  if (ENV_SETENV_IS_ERROR(ret)) {
    lua_pushnil(L);
    lua_pushnumber(L, ret);
    return 2;
  }
  lua_pushboolean(L,1);
  return 1;
#else
#  error "Do not how unset environment variable!"
#endif
}

//}-----------------------------------------

static int l_getenviron(lua_State *L){
  int as_map = lua_toboolean(L,1);
  char **e = environ;
  char *var = NULL;
  int i = 0;
  luaL_checktype(L, 2, LUA_TNONE);

  lua_newtable(L);
  if(as_map) while(var = *(e++)){
    const char *eq = strchr( ('=' == var[0])?&var[1]:&var[0], '=' );
    if(!eq){
      lua_pushstring(L, var);
      lua_rawseti(L,-2,++i);
      continue;
    }
    lua_pushlstring( L, var, eq-var );
    str_upper(L, -1);
    lua_pushstring(L, &eq[1]);
    lua_rawset(L, -3);
  }
  else while(var = *(e++)){
    lua_pushstring(L, var);
    lua_rawseti(L,-2,++i);
  }
  return 1;
}

static int l_getenv(lua_State *L){
  const char *key = luaL_checkstring(L,1);
  const char *value = getenv(key);
  luaL_checktype(L, 2, LUA_TNONE);

  if(!value)
    lua_pushnil(L);
  else
    lua_pushstring(L, value);
  return 1;
}

static int l_setenv(lua_State *L){
  return env_setenv(L);
}

static const struct luaL_Reg env_lib [] = {
  {"environ",      l_getenviron},
  {"get",          l_getenv},
  {"set",          l_setenv},

#if _MSC_VER >= 1400
  {"get_s",     l_getenv_s},
#endif //_MSC_VER

#ifdef ENV_EXPORT_WIN
  {"environ_win",      l_getenviron_win},
  {"expand_win",       l_expenv_win},
  {"set_win",          l_setenv_win},
  {"get_win",          l_getenv_win},
  {"update_win",       l_update_win},
#endif // ENV_EXPORT_WIN

  {NULL, NULL}  /* sentinel */
};

LUALIB_API int luaopen_env (lua_State *L) {
  lua_newtable(L);

#if LUA_VERSION_NUM >= 502 
  luaL_setfuncs(L, env_lib, 0);
#else 
  luaL_openlib(L, NULL, env_lib, 0);
#endif

  return 1;
}

LUALIB_API int luaopen_env_core (lua_State *L) {
  return luaopen_env(L);
}

LUALIB_API int luaopen_ENV_core (lua_State *L) {
  return luaopen_env(L);
}

