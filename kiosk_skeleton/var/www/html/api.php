<?php
header('Content-Type: application/json');

// Load API key from INI file
$iniFile = '/boot/kioskbrowser.ini';
if (!file_exists($iniFile)) {
    http_response_code(500);
    echo json_encode(["error" => "INI file not found"]);
    exit;
}

$config = parse_ini_file($iniFile, true);
$API_KEY = trim($config['api']['key'], "\"'"); // Remove any surrounding quotes

// API key check
if (!isset($_GET['key']) || $_GET['key'] !== $API_KEY) {
    http_response_code(403);
    echo json_encode(["error" => "Forbidden"]);
    exit;
}

// Get action
$action = $_GET['action'] ?? '';

switch ($action) {
    case 'status':
        echo json_encode([
            'temperature' => trim(shell_exec("sudo vcgencmd measure_temp")),
            'voltage'     => trim(shell_exec("sudo vcgencmd measure_volts")),
            'throttled'   => trim(shell_exec("sudo vcgencmd get_throttled")),
            'heartbeat'   => date("Y-m-d H:i:s", filemtime("/dev/shm/heartbeat")),
        ]);
        break;

    case 'screen_off':
        shell_exec("sudo vcgencmd display_power 0");
        echo json_encode(["message" => "Screen turned off"]);
        break;

    case 'screen_on':
        shell_exec("sudo vcgencmd display_power 1");
        echo json_encode(["message" => "Screen turned on"]);
        break;

    case 'screen_refresh':
        shell_exec("sudo systemctl start screen-refresh.service");
        echo json_encode(["message" => "Screen refreshed"]);
        break;

    case 'reboot':
        shell_exec("sudo reboot");
        echo json_encode(["message" => "Rebooting"]);
        break;

    default:
        http_response_code(400);
        echo json_encode(["error" => "Invalid action"]);
        break;
}
?>
