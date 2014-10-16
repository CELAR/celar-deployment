#!/bin/bash
set -e

pushd /opt/slipstream/downloads

cat > slipstream.bootstrap.patch << EOF
--- /opt/slipstream/downloads/slipstream.bootstrap.bak	2014-10-15 16:52:48.666000101 +0100
+++ /opt/slipstream/downloads/slipstream.bootstrap	2014-10-15 16:55:17.516000011 +0100
@@ -167,7 +167,9 @@
             else:
                 # TODO: on Ubuntu 10.04 there is no subprocess.check_output()!!!
                 install_cmd = commands.getoutput('which %s' % pkgmngr)
-                INSTALL_CMD = ['sudo', install_cmd, '-y', 'install']
+                INSTALL_CMD = [install_cmd, '-y', 'install']
+                if os.getuid() != 0:
+                    INSTALL_CMD.insert(0, 'sudo')
                 DISTRO = (pkgmngr == 'apt-get') and 'ubuntu' or 'redhat'
                 if DISTRO == 'ubuntu':
                     subprocess.check_call([install_cmd, '-y', 'update'],
@@ -181,7 +183,10 @@
     if not PIP_INSTALLED:
         _setInstallCommandAndDistro()
         subprocess.check_call(INSTALL_CMD + ['python-setuptools'], stdout=subprocess.PIPE)
-        subprocess.check_call(['sudo', 'easy_install', 'pip'], stdout=subprocess.PIPE)
+        cmd = ['easy_install', 'pip']
+        if os.getuid() != 0:
+            cmd.insert(0, 'sudo')
+        subprocess.check_call(cmd, stdout=subprocess.PIPE)
         PIP_INSTALLED = True
 
 
@@ -192,7 +197,10 @@
 
 def _pipInstall(package):
     _installPip()
-    subprocess.check_call(['sudo', 'pip', 'install', '-I', package],
+    cmd = ['pip', 'install', '-I', package]
+    if os.getuid() != 0:
+        cmd.insert(0, 'sudo')
+    subprocess.check_call(cmd,
                           stdout=subprocess.PIPE)
 
EOF
patch slipstream.bootstrap < slipstream.bootstrap.patch

cat > OrchestratorDeploymentExecutor.py.patch <<EOF
--- lib/slipstream/executors/orchestrator/OrchestratorDeploymentExecutor.py	2014-10-03 00:21:12.000000000 +0100
+++ lib/slipstream/executors/orchestrator/OrchestratorDeploymentExecutor.py.new	2014-10-16 09:58:18.228000230 +0100
@@ -16,6 +16,9 @@
  limitations under the License.
 """
 
+import os
+import subprocess
+
 from slipstream.ConfigHolder import ConfigHolder
 from slipstream.exceptions import Exceptions
 from slipstream.executors.MachineExecutor import MachineExecutor
@@ -28,10 +31,23 @@
         super(OrchestratorDeploymentExecutor, self).__init__(wrapper,
                                                              configHolder)
 
+    @staticmethod
+    def _start_celar_orchestrator():
+        util.printStep('Starting CELAR Orchestrator')
+        start_script = '/opt/celar/celar-orchestrator/bin/celar-orchestrator'
+        if os.path.exists(start_script):
+            rc = subprocess.call([start_script, 'start'])
+            if rc != 0:
+                util.printError("ERROR: Failed to start CELAR Orchestrator")
+        else:
+            util.printDetail("WARNING: CELAR Orchestrator start script not present: %s" % start_script)
+
     @override
     def onProvisioning(self):
         super(OrchestratorDeploymentExecutor, self).onProvisioning()
 
+        self._start_celar_orchestrator()
+ 
         try:
             util.printStep('Starting instances')
             self.wrapper.start_node_instances()
EOF
mkdir slipstreamclient
pushd slipstreamclient
tar -zxf ../slipstreamclient.tgz
patch lib/slipstream/executors/orchestrator/OrchestratorDeploymentExecutor.py \
    < ../OrchestratorDeploymentExecutor.py.patch
tar -zc * -f ../slipstreamclient.tgz
popd
popd
