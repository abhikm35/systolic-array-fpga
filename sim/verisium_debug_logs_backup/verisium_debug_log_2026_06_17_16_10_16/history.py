#########################################################################
# Verisium Debug version 26.05.081-a (Built on 2026-05-28T10:47:24Z)
# history.py generated at 2026/06/17 12:10:16
# host: ece-linlabsrv01
# port: 34261
# launch command: indago -connect dc:ece-linlabsrv01.ece.gatech.edu:58617 -interactive
# #########################################################################
import time, os, sys
if 'self' not in globals():
    from verisium import *
    from verisium.embedded.embedded_utils import indago_help
    self = VerisiumDebugServer(VerisiumDebugArgs(
        is_gui=True,
        is_launch_needed=True,
        port=34261,
        extra_args='-connect dc:ece-linlabsrv01.ece.gatech.edu:58617 -interactive'
    ))

# Verisium: Attempting to connect to Verisium server on host: localhost, port: 34261
# Verisium: **************************************************************************************
# Verisium: *****                        Verisium version 26.05.081-a                        *****
# Verisium: *****                 NOTE: Some API features are Beta quality.                  *****
# Verisium: *****            Consult the <a href="api_reference/beta_apis.html" style="">API documentation</a> for more information.             *****
# Verisium: **************************************************************************************
# # Hint: Use 'self' to reference the running Verisium Debug server. (ex: self.server_info)
# >>> 