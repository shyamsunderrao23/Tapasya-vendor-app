import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static IO.Socket? socket;

  static void disconnect() {
    if (socket != null) {
      print("🔌 [SOCKET] Disconnecting...");
      socket!.disconnect();
      socket!.dispose();
      socket = null;
    }
  }

  static void initSocket(String vendorId) {
    if (socket != null) {
      socket!.emit("vendor_online", vendorId);
      return;
    }

    socket = IO.io(
      "https://tapasyaserver.sreerasthusilvers.co.in", // Backend URL mapped from ApiService
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build(),
    );

    socket!.connect();

    socket!.onConnect((_) {
      print("✅ Connected: ${socket!.id}");

      // Send Vendor Online
      socket!.emit("vendor_online", vendorId);
    });

    socket!.onDisconnect((_) {
      print("❌ Disconnected");
    });

    socket!.onReconnect((_) {
      print("🔄 Reconnected");
      socket!.emit("vendor_online", vendorId);
    });
  }

  static void forceSync(String vendorId) {
    if (socket != null && socket!.connected) {
      print("🚀 [SOCKET] Forcing Sync for Vendor: $vendorId");
      socket!.emit("vendor_online", vendorId);
    }
  }

  static void listenForJobs(Function(dynamic) onNewJob) {
    if (socket == null) return;
    
    // Remove previous listeners to prevent multiple firing if called multiple times
    socket!.off("new_job");
    
    socket!.on("new_job", (data) {
      print("🔥 New Job Received: $data");
      onNewJob(data); 
    });
  }

  static void listenForJobTaken(Function(dynamic) onJobTaken) {
    if (socket == null) return;
    
    socket!.off("job_taken");
    socket!.on("job_taken", (data) {
      print("❌ Job taken by another vendor: $data");
      onJobTaken(data);
    });
  }

  static void listenForJobAssigned(Function(dynamic) onJobAssigned) {
    if (socket == null) return;
    
    socket!.off("job_assigned");
    socket!.on("job_assigned", (data) {
      print("⚡ Auto Assigned Received: $data");
      onJobAssigned(data);
    });
  }

  static void listenForJobUpdate(Function(dynamic) onJobUpdated) {
    if (socket == null) return;
    
    socket!.off("job_updated");
    socket!.on("job_updated", (data) {
      print("🔥 Job Updated Received: $data");
      onJobUpdated(data);
    });
  }
}
