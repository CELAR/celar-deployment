#!/bin/bash
set -e

rpm -q patch > /dev/null || yum install -y patch

pushd /opt/slipstream/downloads

# Properly install dependencies on RedHat-based machine.
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

# Start CELAR Orchestrator.
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

# Add Orchestrator's ssh pub-key on the UserInfo. It then will be used by the 
# connectors to push the keys to the Nodes.
cat > BaseCloudConnector.py.patch <<EOF
--- a/client/src/main/python/slipstream/cloudconnectors/BaseCloudConnector.py
+++ b/client/src/main/python/slipstream/cloudconnectors/BaseCloudConnector.py
@@ -33,7 +33,7 @@ from slipstream.NodeDecorator import NodeDecorator, KEY_RUN_CATEGORY
 from slipstream.listeners.SimplePrintListener import SimplePrintListener
 from slipstream.listeners.SlipStreamClientListenerAdapter import SlipStreamClientListenerAdapter
 from slipstream.utils.ssh import remoteRunScriptNohup, waitUntilSshCanConnectOrTimeout, remoteRunScript, \\
-                                 remoteInstallPackages, generate_keypair
+                                 remoteInstallPackages, generate_keypair, generate_ssh_keypair
 from slipstream.utils.tasksrunner import TasksRunner
 from slipstream.wrappers.BaseWrapper import NodeInfoPublisher
 from winrm.winrm_service import WinRMWebService
@@ -251,11 +251,21 @@ class BaseCloudConnector(object):
         if self.__tasks_runnner != None:
             self.__tasks_runnner.wait_tasks_processed()
 
+    def _add_orchestrator_ssh_pub_key(self, user_info):
+        ssh_pub_keys = user_info.get_public_keys()
+        if not os.path.exists(self.sshPubKeyFile):
+            generate_ssh_keypair(self.sshPrivKeyFile)
+        ssh_pub_keys += '\n' + util.fileGetContent(self.sshPubKeyFile)
+        user_info[user_info.general + '.ssh.public.key'] = ssh_pub_keys
+
     def __start_node_instance_and_client(self, user_info, node_instance):
         node_instance_name = node_instance.get_name()
 
         self._print_detail("Starting instance: %s" % node_instance_name)
 
+        if not self.isStartOrchestrator():
+            self._add_orchestrator_ssh_pub_key(user_info)
+
         vm = self._start_image(user_info,
                                node_instance,
                                self._generate_vm_name(node_instance_name))
EOF

mkdir slipstreamclient
pushd slipstreamclient
tar -zxf ../slipstreamclient.tgz
patch lib/slipstream/executors/orchestrator/OrchestratorDeploymentExecutor.py \
    < ../OrchestratorDeploymentExecutor.py.patch
patch lib/slipstream/cloudconnectors/BaseCloudConnector.py \
    < ../BaseCloudConnector.py.patch
tar -zc * -f ../slipstreamclient.tgz
popd
popd
