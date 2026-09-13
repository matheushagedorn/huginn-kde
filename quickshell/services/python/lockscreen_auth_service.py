#!/usr/bin/env python3
import sys
import os
import shutil
import subprocess
import ctypes
import ctypes.util
import getpass
import concurrent.futures

# ------------------------------------------------------------------------------
# 1. Direct unix_chkpwd PAM Engine (Fastest & Most Reliable on Linux)
# ------------------------------------------------------------------------------
def verify_via_unix_chkpwd(username, password):
    chk_paths = [
        '/run/wrappers/bin/unix_chkpwd',
        '/run/current-system/sw/bin/unix_chkpwd',
        '/usr/bin/unix_chkpwd',
        '/sbin/unix_chkpwd',
        '/usr/sbin/unix_chkpwd'
    ]
    for chk_path in chk_paths:
        if os.path.exists(chk_path):
            try:
                proc = subprocess.Popen(
                    [chk_path, username, 'nullok'],
                    stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE
                )
                pwd_input = password.encode('utf-8') + b'\x00'
                proc.communicate(input=pwd_input, timeout=0.5)
                return (True, proc.returncode == 0)
            except Exception:
                pass
    return (False, False)

# ------------------------------------------------------------------------------
# 2. C libpam API Engine
# ------------------------------------------------------------------------------
def verify_via_libpam(username, password):
    try:
        libpam_path = ctypes.util.find_library('pam') or '/run/current-system/sw/lib/libpam.so' or 'libpam.so.0'
        if not libpam_path:
            return False
        libpam = ctypes.CDLL(libpam_path)
        libc = ctypes.CDLL(None)
        libc.calloc.restype = ctypes.c_void_p
        libc.calloc.argtypes = [ctypes.c_size_t, ctypes.c_size_t]
        libc.strdup.restype = ctypes.c_void_p
        libc.strdup.argtypes = [ctypes.c_char_p]

        class PamMessage(ctypes.Structure):
            _fields_ = [('msg_style', ctypes.c_int), ('msg', ctypes.c_char_p)]

        class PamResponse(ctypes.Structure):
            _fields_ = [('resp', ctypes.c_void_p), ('resp_retcode', ctypes.c_int)]

        PamConvFunc = ctypes.CFUNCTYPE(
            ctypes.c_int,
            ctypes.c_int,
            ctypes.POINTER(ctypes.POINTER(PamMessage)),
            ctypes.POINTER(ctypes.POINTER(PamResponse)),
            ctypes.c_void_p
        )

        class PamConv(ctypes.Structure):
            _fields_ = [('conv', PamConvFunc), ('appdata_ptr', ctypes.c_void_p)]

        def _py_pam_conv(n_messages, messages, p_response, appdata_ptr):
            if not appdata_ptr or not libc:
                return 19
            arr = libc.calloc(n_messages, ctypes.sizeof(PamResponse))
            responses = ctypes.cast(arr, ctypes.POINTER(PamResponse))
            for i in range(n_messages):
                msg = messages[i].contents
                if msg.msg_style in (1, 2):
                    p_bytes = ctypes.cast(appdata_ptr, ctypes.c_char_p).value
                    if p_bytes:
                        responses[i].resp = libc.strdup(p_bytes)
                        responses[i].resp_retcode = 0
            p_response[0] = responses
            return 0

        conv_func = PamConvFunc(_py_pam_conv)
        pwd_bytes = password.encode('utf-8')
        pwd_buf = ctypes.c_char_p(pwd_bytes)
        conv = PamConv(conv_func, ctypes.cast(pwd_buf, ctypes.c_void_p))

        for service in ['passwd', 'login', 'system-auth', 'sddm']:
            try:
                pamh = ctypes.c_void_p()
                res = libpam.pam_start(service.encode('utf-8'), username.encode('utf-8'), ctypes.byref(conv), ctypes.byref(pamh))
                if res == 0:
                    auth_res = libpam.pam_authenticate(pamh, 0)
                    libpam.pam_end(pamh, auth_res)
                    if auth_res == 0:
                        return True
            except Exception:
                pass
    except Exception:
        pass
    return False

def verify_password(username, password):
    if not password:
        return False

    # 1. Try unix_chkpwd first for instant verification (<2ms)
    executed, success = verify_via_unix_chkpwd(username, password)
    if executed:
        return success

    # 2. Fallback to PAM API only if unix_chkpwd is unavailable
    return verify_via_libpam(username, password)

def main():
    password = ""
    if len(sys.argv) >= 2:
        password = sys.argv[1]
    else:
        password = sys.stdin.read().strip()

    username = getpass.getuser()
    if len(sys.argv) >= 3:
        username = sys.argv[2].strip()

    success = verify_password(username, password)
    if success:
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == '__main__':
    main()
