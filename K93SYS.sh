#!/bin/bash

# Get the directory of the currently running script
script_path=$(dirname "$(realpath "$0")")

# Source the configuration file from the same directory
source "$script_path/config.conf"
version="2.0.0-RC.1"

net_monitor_freq=".5" #$((net_freq / 4))

mqtt_connection_throttle=".1"

mqtt_device="$mqtt_devicename"

status="run"
pids=()  # Array to store background process IDs

# Function to clean up background processes
cleanup() {
    echo "Stopping script..."
    rm k93sys.log
    pkill -f -9 *K93SYS.sh*
    pkill -f -9 mosquitto_sub*
    for pid in "${pids[@]}"; do
        kill "$pid" 2>/dev/null
    done
    mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t $mqtt_topic/$mqtt_device-status -m 'offline'
    exit 0
}

# Trap signals (e.g., CTRL+C or kill)
trap cleanup SIGINT SIGTERM

BRIGHT_BLACK='\033[1;30m'  # Bright Black (Gray)
BRIGHT_RED='\033[1;31m'    # Bright Red
BRIGHT_GREEN='\033[1;32m'  # Bright Green
BRIGHT_YELLOW='\033[1;33m' # Bright Yellow
BRIGHT_BLUE='\033[1;34m'   # Bright Blue
BRIGHT_PURPLE='\033[1;35m' # Bright Purple
BRIGHT_CYAN='\033[1;36m'   # Bright Cyan
BRIGHT_WHITE='\033[1;37m'  # Bright White
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'  # Reset color
BOLD='\033[1m'  # Bold text

log=""
current_time=$(date +'%H:%M:%S')
rm k93sys.log
touch k93sys.log
# Function to add a log entry
log_file="k93sys.log"
add_log_entry() {
    timestamp=$(date +"%H:%M:%S")  # Get current time in hh:mm:ss format
    log_entry="$timestamp $1"  # Prepend the timestamp to the log entry
    echo "$log_entry" >> "$log_file"  # Append the log entry to the log file
}

clear
header_lines=10  # Number of lines for the header
max_log_lines=28

if [[ $app_tui == "true" ]]
    then
    # Function to display the header
    display_header() {
        echo -e "${BRIGHT_PURPLE}###############################################################################"
        echo -e "${BRIGHT_PURPLE}#                                ${BRIGHT_RED}${BOLD}K93SYS-NIX-DAEMON${RESET}                            ${BRIGHT_PURPLE}#"
        echo -e "${BRIGHT_PURPLE}#                               ${BRIGHT_PURPLE}Version ${CYAN}${BOLD}$version${RESET}                            ${BRIGHT_PURPLE}#"
        echo -e "${BRIGHT_PURPLE}#                      ${GREEN}bash MQTT client by Henrik Ludvigsen                   ${BRIGHT_PURPLE}#"
        echo -e "${BRIGHT_PURPLE}#                           ${YELLOW}www.github.com/henriklud                          ${BRIGHT_PURPLE}#"
        echo -e "${BRIGHT_PURPLE}###############################################################################"
        echo -e "${BOLD}${BRIGHT_YELLOW}Host: ${RESET}${BRIGHT_WHITE}$mqtt_devicename"
        echo -e "${BOLD}${BRIGHT_YELLOW}MQTT-Broker: ${RESET}${BRIGHT_WHITE}$server"
        echo -e "${BOLD}${BRIGHT_YELLOW}MQTT-Topic: ${RESET}${BRIGHT_WHITE}$mqtt_topic"        
        echo -e "${BRIGHT_PURPLE}[]---------------------------------------------------------------------------[]${RESET}"
        lines=$(tput lines)
    }
fi
if [[ $app_tui == "true" ]]
    then
    # Function to manage log size (clear log if it exceeds the maximum number of lines)
    manage_log_size() {
    #  max_log_lines=3
        log_lines=$(wc -l < "$log_file")  # Get the current number of lines in the log file
        if [ "$log_lines" -gt "$max_log_lines" ]; then
            # If the log exceeds the max allowed lines, truncate it
            tail -n "$max_log_lines" "$log_file" > "$log_file.tmp" && mv "$log_file.tmp" "$log_file"
        fi
    }

    # Main loop
    (
        while :; do
            # Get terminal height and subtract space for the header
            rows=$(tput lines)
            log_height=$((rows - header_lines))  # Calculate space available for logs

            # Display the header only once
            if [ -z "$header_displayed" ]; then
                display_header
                header_displayed=true
            fi

            # Clear only the log area (below the header)
            tput cup $header_lines 0  # Move cursor to the start of the log area
            tput ed  # Clear everything below the current cursor position (log area)

            # Manage log size: clear log if it exceeds the max size
            manage_log_size

            # Display the log (scrolling only the log area)
            tput cup $header_lines 0  # Move cursor to the start of the log area
            tail -n $log_height "$log_file"  # Display the last $log_height lines of the log

            # Wait before updating the screen again
            sleep 3s
        done&
    )&
    pids+=($!)
fi

# Initialization
sleep 2s

if [[ $app_tui == "true" ]]
    then
        add_log_entry "Connenction to broker at $server..."
fi

log_file="k93sys.log"        
device_manufacturer="Henrik I. Ludvigsen"
device_model="K93SYS Linux Daemon"
device_sn="K93-69420"
device_modelid="K93SYS-NIX-DAEMON"

sleep 3s
(
    while :; do

        add_log_entry() {
            timestamp=$(date +"%H:%M:%S")  # Get current time in hh:mm:ss format
            log_entry="$timestamp $1"  # Prepend the timestamp to the log entry
            echo "$log_entry" >> "$log_file"  # Append the log entry to the log file
        }

        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
        -t "$mqtt_discovery_prefix/sensor/$mqtt_device/processes/config" \
        -m "{\"unique_id\": \"$mqtt_device-processes\", \"icon\": \"mdi:tools\", \"name\": \"Running Processes\", \"state_topic\": \"$mqtt_topic/$mqtt_device/processes\", \"unit_of_measurement\": \"\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
        -t "$mqtt_discovery_prefix/sensor/$mqtt_device/kvm_vms/config" \
        -m "{\"unique_id\": \"$mqtt_device-kvm_vms\", \"icon\": \"mdi:console\", \"name\": \"Running KVM VMs\", \"state_topic\": \"$mqtt_topic/$mqtt_device/kvm_vms\", \"unit_of_measurement\": \"\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
        -t "$mqtt_discovery_prefix/sensor/$mqtt_device/lxc_containers/config" \
        -m "{\"unique_id\": \"$mqtt_device-lxc_containers\", \"icon\": \"mdi:console\", \"name\": \"Running LXC Containers\", \"state_topic\": \"$mqtt_topic/$mqtt_device/lxc_containers\", \"unit_of_measurement\": \"\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"

        # Publish Public IP Data
        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
        -t "$mqtt_discovery_prefix/sensor/$mqtt_device/public_ip/config" \
        -m "{\"unique_id\": \"$mqtt_device-public_ip\", \"icon\": \"mdi:network\", \"name\": \"Public IP\", \"state_topic\": \"$mqtt_topic/$mqtt_device/public_ip\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
        sleep $mqtt_connection_throttle
        # Publish CPU Name Data
        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
        -t "$mqtt_discovery_prefix/sensor/$mqtt_device/cpu_name/config" \
        -m "{\"unique_id\": \"$mqtt_device-cpu_name\", \"icon\": \"mdi:cpu-64-bit\", \"name\": \"CPU Name\", \"state_topic\": \"$mqtt_topic/$mqtt_device/cpu_name\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
        sleep $mqtt_connection_throttle
        # Publish Kernel Version Data & hostname
        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
        -t "$mqtt_discovery_prefix/sensor/$mqtt_device/kernel_version/config" \
        -m "{\"unique_id\": \"$mqtt_device-kernel_version\", \"icon\": \"mdi:penguin\", \"name\": \"Kernel Version\", \"state_topic\": \"$mqtt_topic/$mqtt_device/kernel_version\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
        -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hostname/config" \
        -m "{\"unique_id\": \"$mqtt_device-hostname\", \"icon\": \"mdi:server\", \"name\": \"hostname\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hostname\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
        sleep $mqtt_connection_throttle
        # Components init - Discovery configuration topics \"icon\": \"mdi:thermometer\", 

        ################################
        #   LM-SENSORS                 #
        ################################
        if [[ $lmsnsr_enabled == "true" ]]
            then

                # lmsnsr_1
                if [[ $lmsnsr_1_enabled == "true" ]]
                    then
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$lmsnsr_1_id/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"$lmsnsr_1_icon\", \"unique_id\": \"$mqtt_device-$lmsnsr_1_id\", \"name\": \"$lmsnsr_1_name\", \"value_template\": \"$lmsnsr_1_value_template\", \"state_topic\": \"$mqtt_topic/$mqtt_device/lm_sensors\", \"unit_of_measurement\": \"$lmsnsr_1_unit_of_measurement\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle
                fi

                # lmsnsr_2
                if [[ $lmsnsr_2_enabled == "true" ]]
                    then
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$lmsnsr_2_id/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"$lmsnsr_2_icon\", \"unique_id\": \"$mqtt_device-$lmsnsr_2_id\", \"name\": \"$lmsnsr_2_name\", \"value_template\": \"$lmsnsr_2_value_template\", \"state_topic\": \"$mqtt_topic/$mqtt_device/lm_sensors\", \"unit_of_measurement\": \"$lmsnsr_2_unit_of_measurement\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle
                fi

                # lmsnsr_3
                if [[ $lmsnsr_3_enabled == "true" ]]
                    then
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$lmsnsr_3_id/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"$lmsnsr_3_icon\", \"unique_id\": \"$mqtt_device-$lmsnsr_3_id\", \"name\": \"$lmsnsr_3_name\", \"value_template\": \"$lmsnsr_3_value_template\", \"state_topic\": \"$mqtt_topic/$mqtt_device/lm_sensors\", \"unit_of_measurement\": \"$lmsnsr_3_unit_of_measurement\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle
                fi

                # lmsnsr_4
                if [[ $lmsnsr_4_enabled == "true" ]]
                    then
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$lmsnsr_4_id/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"$lmsnsr_4_icon\", \"unique_id\": \"$mqtt_device-$lmsnsr_4_id\", \"name\": \"$lmsnsr_4_name\", \"value_template\": \"$lmsnsr_4_value_template\", \"state_topic\": \"$mqtt_topic/$mqtt_device/lm_sensors\", \"unit_of_measurement\": \"$lmsnsr_4_unit_of_measurement\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle
                fi

                # lmsnsr_5
                if [[ $lmsnsr_5_enabled == "true" ]]
                    then
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$lmsnsr_5_id/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"$lmsnsr_5_icon\", \"unique_id\": \"$mqtt_device-$lmsnsr_5_id\", \"name\": \"$lmsnsr_5_name\", \"value_template\": \"$lmsnsr_5_value_template\", \"state_topic\": \"$mqtt_topic/$mqtt_device/lm_sensors\", \"unit_of_measurement\": \"$lmsnsr_5_unit_of_measurement\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle
                fi

                # lmsnsr_6
                if [[ $lmsnsr_6_enabled == "true" ]]
                    then
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$lmsnsr_6_id/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"$lmsnsr_6_icon\", \"unique_id\": \"$mqtt_device-$lmsnsr_6_id\", \"name\": \"$lmsnsr_6_name\", \"value_template\": \"$lmsnsr_6_value_template\", \"state_topic\": \"$mqtt_topic/$mqtt_device/lm_sensors\", \"unit_of_measurement\": \"$lmsnsr_6_unit_of_measurement\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle
                fi

                # lmsnsr_7
                if [[ $lmsnsr_7_enabled == "true" ]]
                    then
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$lmsnsr_7_id/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"$lmsnsr_7_icon\", \"unique_id\": \"$mqtt_device-$lmsnsr_7_id\", \"name\": \"$lmsnsr_7_name\", \"value_template\": \"$lmsnsr_7_value_template\", \"state_topic\": \"$mqtt_topic/$mqtt_device/lm_sensors\", \"unit_of_measurement\": \"$lmsnsr_7_unit_of_measurement\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle
                fi

                # lmsnsr_8
                if [[ $lmsnsr_8_enabled == "true" ]]
                    then
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$lmsnsr_8_id/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"$lmsnsr_8_icon\", \"unique_id\": \"$mqtt_device-$lmsnsr_8_id\", \"name\": \"$lmsnsr_8_name\", \"value_template\": \"$lmsnsr_8_value_template\", \"state_topic\": \"$mqtt_topic/$mqtt_device/lm_sensors\", \"unit_of_measurement\": \"$lmsnsr_8_unit_of_measurement\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle
                fi

                # lmsnsr_9
                if [[ $lmsnsr_9_enabled == "true" ]]
                    then
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$lmsnsr_9_id/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"$lmsnsr_9_icon\", \"unique_id\": \"$mqtt_device-$lmsnsr_9_id\", \"name\": \"$lmsnsr_9_name\", \"value_template\": \"$lmsnsr_9_value_template\", \"state_topic\": \"$mqtt_topic/$mqtt_device/lm_sensors\", \"unit_of_measurement\": \"$lmsnsr_9_unit_of_measurement\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle
                fi

                # lmsnsr_10
                if [[ $lmsnsr_10_enabled == "true" ]]
                    then
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$lmsnsr_10_id/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"$lmsnsr_10_icon\", \"unique_id\": \"$mqtt_device-$lmsnsr_10_id\", \"name\": \"$lmsnsr_10_name\", \"value_template\": \"$lmsnsr_10_value_template\", \"state_topic\": \"$mqtt_topic/$mqtt_device/lm_sensors\", \"unit_of_measurement\": \"$lmsnsr_10_unit_of_measurement\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle
                fi
        fi



        if [[ $nic_1_enabled == "true" ]]
            then
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                    -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$nic_1_interface"_out"/config" \
                    -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:ethernet\", \"unique_id\": \"$mqtt_device-nic_1-out\",\"name\": \"$nic_1_interface out\", \"state_topic\": \"$mqtt_topic/$mqtt_device/nic_1_out\", \"unit_of_measurement\": \"mbit/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                    -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$nic_1_interface"_in"/config" \
                    -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:ethernet\", \"unique_id\": \"$mqtt_device-nic_1-in\",\"name\": \"$nic_1_interface in\", \"state_topic\": \"$mqtt_topic/$mqtt_device/nic_1_in\", \"unit_of_measurement\": \"mbit/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"

        fi

        if [[ $nic_2_enabled == "true" ]]
            then
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                    -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$nic_2_interface"_out"/config" \
                    -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:ethernet\", \"unique_id\": \"$mqtt_device-nic_2-out\",\"name\": \"$nic_2_interface out\", \"state_topic\": \"$mqtt_topic/$mqtt_device/nic_2_out\", \"unit_of_measurement\": \"mbit/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                    -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$nic_2_interface"_in"/config" \
                    -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:ethernet\", \"unique_id\": \"$mqtt_device-nic_2-in\",\"name\": \"$nic_2_interface in\", \"state_topic\": \"$mqtt_topic/$mqtt_device/nic_2_in\", \"unit_of_measurement\": \"mbit/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"

        fi

        if [[ $nic_3_enabled == "true" ]]
            then
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                    -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$nic_3_interface"_out"/config" \
                    -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:ethernet\", \"unique_id\": \"$mqtt_device-nic_3-out\",\"name\": \"$nic_3_interface out\", \"state_topic\": \"$mqtt_topic/$mqtt_device/nic_3_out\", \"unit_of_measurement\": \"mbit/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                    -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$nic_3_interface"_in"/config" \
                    -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:ethernet\", \"unique_id\": \"$mqtt_device-nic_3-in\",\"name\": \"$nic_3_interface in\", \"state_topic\": \"$mqtt_topic/$mqtt_device/nic_3_in\", \"unit_of_measurement\": \"mbit/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"

        fi

        if [[ $nic_4_enabled == "true" ]]
            then
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                    -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$nic_4_interface"_out"/config" \
                    -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:ethernet\", \"unique_id\": \"$mqtt_device-nic_4-out\",\"name\": \"$nic_4_interface out\", \"state_topic\": \"$mqtt_topic/$mqtt_device/nic_4_out\", \"unit_of_measurement\": \"mbit/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                    -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$nic_4_interface"_in"/config" \
                    -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:ethernet\", \"unique_id\": \"$mqtt_device-nic_4-in\",\"name\": \"$nic_4_interface in\", \"state_topic\": \"$mqtt_topic/$mqtt_device/nic_4_in\", \"unit_of_measurement\": \"mbit/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"

        fi

        if [[ $nic_5_enabled == "true" ]]
            then
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                    -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$nic_5_interface_"_out"/config" \
                    -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:ethernet\", \"unique_id\": \"$mqtt_device-nic_5-out\",\"name\": \"$nic_5_interface out\", \"state_topic\": \"$mqtt_topic/$mqtt_device/nic_5_out\", \"unit_of_measurement\": \"mbit/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                    -t "$mqtt_discovery_prefix/sensor/$mqtt_device/$nic_5_interface"_in"/config" \
                    -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:ethernet\", \"unique_id\": \"$mqtt_device-nic_5-in\",\"name\": \"$nic_5_interface in\", \"state_topic\": \"$mqtt_topic/$mqtt_device/nic_5_in\", \"unit_of_measurement\": \"mbit/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"

        fi




        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/cpu_load/config" \
            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:cpu-64-bit\", \"unique_id\": \"$mqtt_device-cpu_load\",\"name\": \"cpu_load\", \"state_topic\": \"$mqtt_topic/$mqtt_device/cpu_load\", \"unit_of_measurement\": \"%\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
        sleep $mqtt_connection_throttle
        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/memory_used/config" \
            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:memory\", \"unique_id\": \"$mqtt_device-memory_used\",\"name\": \"memory_used\", \"state_topic\": \"$mqtt_topic/$mqtt_device/memory_used\", \"unit_of_measurement\": \"MB\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
        sleep $mqtt_connection_throttle

        if [[ $hddmon_enabled == "true" ]]
            then



                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                    -t "$mqtt_discovery_prefix/sensor/$mqtt_device/storage_reads/config" \
                    -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-storage_reads\",\"name\": \"storage_reads\", \"state_topic\": \"$mqtt_topic/$mqtt_device/storage_reads\", \"unit_of_measurement\": \"MB/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                    -t "$mqtt_discovery_prefix/sensor/$mqtt_device/storage_writes/config" \
                    -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-storage_writes\",\"name\": \"storage_writes\", \"state_topic\": \"$mqtt_topic/$mqtt_device/storage_writes\", \"unit_of_measurement\": \"MB/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                sleep $mqtt_connection_throttle

                if [[ $hddmon_1_enabled == "true" ]]
                    then

                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_1_used_space/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_1_used_space\",\"name\": \"$hddmon_1_name used space\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_1_used_space\", \"unit_of_measurement\": \"GB\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle

                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_1_free_space/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_1_free_space\",\"name\": \"$hddmon_1_name free space\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_1_free_space\", \"unit_of_measurement\": \"GB\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle

                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_1_total_space/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_1_total_space\",\"name\": \"$hddmon_1_name total space\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_1_total_space\", \"unit_of_measurement\": \"GB\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle

                        # Publish HDD1 Data
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_1_reads/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_1_reads\",\"name\": \"$hddmon_1_name reads\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_1_reads\", \"unit_of_measurement\": \"MB/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                    
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_1_writes/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_1_writes\",\"name\": \"$hddmon_1_name writes\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_1_writes\", \"unit_of_measurement\": \"MB/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                        sleep $mqtt_connection_throttle
                        
                        # Publish HDD1 Model Configuration (Icon: mdi:tag)
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_1_model/config" \
                            -m "{\"unique_id\": \"$mqtt_device-hddmon_1_model\", \"name\": \"$hddmon_1_name model\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_1_model\", \"icon\": \"mdi:tag\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                        sleep $mqtt_connection_throttle
                        
                        # Publish HDD1 SMART Errors Configuration (Icon: mdi:alert-circle)
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_1_smart_errors/config" \
                            -m "{\"unique_id\": \"$mqtt_device-hddmon_1_smart_errors\", \"name\": \"$hddmon_1_name smart errors\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_1_smart_errors\", \"icon\": \"mdi:alert-circle\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                        sleep $mqtt_connection_throttle        

                fi

                if [[ $hddmon_2_enabled == "true" ]]
                    then

                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_2_used_space/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_2_used_space\",\"name\": \"$hddmon_2_name used space\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_2_used_space\", \"unit_of_measurement\": \"GB\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle

                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_2_free_space/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_2_free_space\",\"name\": \"$hddmon_2_name free space\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_2_free_space\", \"unit_of_measurement\": \"GB\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle

                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_2_total_space/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_2_total_space\",\"name\": \"$hddmon_2_name total space\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_2_total_space\", \"unit_of_measurement\": \"GB\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle

                        # Publish HDD1 Data
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_2_reads/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_2_reads\",\"name\": \"$hddmon_2_name reads\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_2_reads\", \"unit_of_measurement\": \"MB/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                    
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_2_writes/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_2_writes\",\"name\": \"$hddmon_2_name writes\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_2_writes\", \"unit_of_measurement\": \"MB/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                        sleep $mqtt_connection_throttle
                        
                        # Publish HDD1 Model Configuration (Icon: mdi:tag)
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_2_model/config" \
                            -m "{\"unique_id\": \"$mqtt_device-hddmon_2_model\", \"name\": \"$hddmon_2_name model\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_2_model\", \"icon\": \"mdi:tag\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                        sleep $mqtt_connection_throttle
                        
                        # Publish HDD1 SMART Errors Configuration (Icon: mdi:alert-circle)
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_2_smart_errors/config" \
                            -m "{\"unique_id\": \"$mqtt_device-hddmon_2_smart_errors\", \"name\": \"$hddmon_2_name smart errors\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_2_smart_errors\", \"icon\": \"mdi:alert-circle\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                        sleep $mqtt_connection_throttle        

                fi

                if [[ $hddmon_3_enabled == "true" ]]
                    then

                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_3_used_space/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_3_used_space\",\"name\": \"$hddmon_3_name used space\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_3_used_space\", \"unit_of_measurement\": \"GB\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle

                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_3_free_space/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_3_free_space\",\"name\": \"$hddmon_3_name free space\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_3_free_space\", \"unit_of_measurement\": \"GB\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle

                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_3_total_space/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_3_total_space\",\"name\": \"$hddmon_3_name total space\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_3_total_space\", \"unit_of_measurement\": \"GB\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle

                        # Publish HDD1 Data
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_3_reads/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_3_reads\",\"name\": \"$hddmon_3_name reads\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_3_reads\", \"unit_of_measurement\": \"MB/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                    
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_3_writes/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_3_writes\",\"name\": \"$hddmon_3_name writes\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_3_writes\", \"unit_of_measurement\": \"MB/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                        sleep $mqtt_connection_throttle
                        
                        # Publish HDD1 Model Configuration (Icon: mdi:tag)
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_3_model/config" \
                            -m "{\"unique_id\": \"$mqtt_device-hddmon_3_model\", \"name\": \"$hddmon_3_name model\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_3_model\", \"icon\": \"mdi:tag\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                        sleep $mqtt_connection_throttle
                        
                        # Publish HDD1 SMART Errors Configuration (Icon: mdi:alert-circle)
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_3_smart_errors/config" \
                            -m "{\"unique_id\": \"$mqtt_device-hddmon_3_smart_errors\", \"name\": \"$hddmon_3_name smart errors\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_3_smart_errors\", \"icon\": \"mdi:alert-circle\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                        sleep $mqtt_connection_throttle        

                fi

                if [[ $hddmon_4_enabled == "true" ]]
                    then

                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_4_used_space/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_4_used_space\",\"name\": \"$hddmon_4_name used space\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_4_used_space\", \"unit_of_measurement\": \"GB\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle

                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_4_free_space/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_4_free_space\",\"name\": \"$hddmon_4_name free space\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_4_free_space\", \"unit_of_measurement\": \"GB\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle

                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_4_total_space/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_4_total_space\",\"name\": \"$hddmon_4_name total space\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_4_total_space\", \"unit_of_measurement\": \"GB\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle

                        # Publish HDD1 Data
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_4_reads/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_4_reads\",\"name\": \"$hddmon_4_name reads\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_4_reads\", \"unit_of_measurement\": \"MB/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                    
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_4_writes/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_4_writes\",\"name\": \"$hddmon_4_name writes\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_4_writes\", \"unit_of_measurement\": \"MB/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                        sleep $mqtt_connection_throttle
                        
                        # Publish HDD1 Model Configuration (Icon: mdi:tag)
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_4_model/config" \
                            -m "{\"unique_id\": \"$mqtt_device-hddmon_4_model\", \"name\": \"$hddmon_4_name model\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_4_model\", \"icon\": \"mdi:tag\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                        sleep $mqtt_connection_throttle
                        
                        # Publish HDD1 SMART Errors Configuration (Icon: mdi:alert-circle)
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_4_smart_errors/config" \
                            -m "{\"unique_id\": \"$mqtt_device-hddmon_4_smart_errors\", \"name\": \"$hddmon_4_name smart errors\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_4_smart_errors\", \"icon\": \"mdi:alert-circle\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                        sleep $mqtt_connection_throttle        

                fi

                if [[ $hddmon_5_enabled == "true" ]]
                    then

                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_5_used_space/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_5_used_space\",\"name\": \"$hddmon_5_name used space\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_5_used_space\", \"unit_of_measurement\": \"GB\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle

                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_5_free_space/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_5_free_space\",\"name\": \"$hddmon_5_name free space\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_5_free_space\", \"unit_of_measurement\": \"GB\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle

                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_5_total_space/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_5_total_space\",\"name\": \"$hddmon_5_name total space\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_5_total_space\", \"unit_of_measurement\": \"GB\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
                        sleep $mqtt_connection_throttle

                        # Publish HDD1 Data
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_5_reads/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_5_reads\",\"name\": \"$hddmon_5_name reads\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_5_reads\", \"unit_of_measurement\": \"MB/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                    
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_5_writes/config" \
                            -m "{\"suggested_display_precision\": \"2\", \"state_class\": \"MEASUREMENT\", \"icon\": \"mdi:harddisk\", \"unique_id\": \"$mqtt_device-hddmon_5_writes\",\"name\": \"$hddmon_5_name writes\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_5_writes\", \"unit_of_measurement\": \"MB/s\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                        sleep $mqtt_connection_throttle
                        
                        # Publish HDD1 Model Configuration (Icon: mdi:tag)
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_5_model/config" \
                            -m "{\"unique_id\": \"$mqtt_device-hddmon_5_model\", \"name\": \"$hddmon_5_name model\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_5_model\", \"icon\": \"mdi:tag\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                        sleep $mqtt_connection_throttle
                        
                        # Publish HDD1 SMART Errors Configuration (Icon: mdi:alert-circle)
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
                            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/hddmon_5_smart_errors/config" \
                            -m "{\"unique_id\": \"$mqtt_device-hddmon_5_smart_errors\", \"name\": \"$hddmon_5_name smart errors\", \"state_topic\": \"$mqtt_topic/$mqtt_device/hddmon_5_smart_errors\", \"icon\": \"mdi:alert-circle\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"manufacturer\": \"K93SYS\"}}"
                        sleep $mqtt_connection_throttle        

                fi


        fi

        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/iowait/config" \
            -m "{\"unique_id\": \"$mqtt_device-iowait\",\"name\": \"iowait\", \"state_topic\": \"$mqtt_topic/$mqtt_device/iowait\", \"unit_of_measurement\": \"%\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
        sleep $mqtt_connection_throttle

        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/updates_available/config" \
            -m "{\"unique_id\": \"$mqtt_device-updates_available\",\"name\": \"updates_available\", \"state_topic\": \"$mqtt_topic/$mqtt_device/updates_available\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"
        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd \
            -t "$mqtt_discovery_prefix/sensor/$mqtt_device/uptime/config" \
            -m "{\"unique_id\": \"$mqtt_device-uptime\",\"name\": \"uptime\", \"state_topic\": \"$mqtt_topic/$mqtt_device/uptime\", \"device\": {\"identifiers\": [\"$mqtt_device\"], \"name\": \"$mqtt_devicename\", \"sw_version\": \"$version\", \"model\": \"$device_model\", \"model_id\": \"$device_modelid\", \"serial_number\": \"$device_sn\", \"manufacturer\": \"$device_manufacturer\"}}"


        source "$script_path/bin/discovery-msg.conf"
        if [[ $app_tui == "true" ]]
            then
                add_log_entry "Entity-configs published to the MQTT-Broker!"
        fi
        sleep 30s    
    done&
)&
pids+=($!)  # Add PID to the list




sleep 3s
if [[ $app_tui == "true" ]]
    then
        add_log_entry "Starting workers..."
fi
sleep 1s


# MQTT keep-alive loop
(
    while :; do  
        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t $mqtt_topic/$mqtt_device-status -m 'online'
        sleep 30s
    done
)&
pids+=($!)

# Listen for MQTT commands
(
    while :; do
        mosquitto_sub -h "$server" -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/exe-cmd/state" | while read -r execmd_payload; do
            if [[ $execmd_payload != "ready" ]]; then
                log+="$log \n executing ${execmd_payload}"        
                echo "Cmd received, executing: ${execmd_payload}"
                $execmd_payload
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t $mqtt_topic/$mqtt_device/exe-cmd/state -m "ready"
            fi
        done
        sleep 1s  
    done&
)&
pids+=($!)

# Status data publishing loop
(
    while :; do
        log_file="k93sys.log"        
        add_log_entry() {
            timestamp=$(date +"%H:%M:%S")  # Get current time in hh:mm:ss format
            log_entry="$timestamp $1"  # Prepend the timestamp to the log entry
            echo "$log_entry" >> "$log_file"  # Append the log entry to the log file
        } 

        updates_available=$(eval "$cmd_updates_available")
        uptime_seconds=$(eval "$cmd_uptime_seconds")
        uptime=$(eval "$cmd_uptime")
        kernel_version=$(eval "$cmd_kernel_version")
        hostname=$(eval "$cmd_hostname")
        cpu_name=$(eval "$cmd_cpu_name")
        public_ip=$(eval "$cmd_public_ip")
        processes=$(eval "$cmd_processes")
        kvm_vms=$(eval "$cmd_kvm_vms")
        lxc_containers=$(eval "$cmd_lxc_containers")

        source "$script_path/bin/status-fetch.conf"  
        sleep .5s

        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/updates_available" -m "$updates_available"
        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/uptime" -m "$uptime"
        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/kernel_version" -m "$kernel_version"
        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hostname" -m "$hostname"
        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/cpu_name" -m "$cpu_name"
        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/public_ip" -m "$public_ip"

        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/processes" -m "$processes"
        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/kvm_vms" -m "$kvm_vms"
        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/lxc_containers" -m "$lxc_containers"

        source "$script_path/bin/status-post.conf"  
        if [[ $app_tui == "true" ]]
            then
                add_log_entry "updates_available: $updates_available | uptime: $uptime"
        fi
        sleep $status_freq
    done&
)&
pids+=($!)


# Component data publishing loop
(
    while :; do
        add_log_entry() {
            timestamp=$(date +"%H:%M:%S")  # Get current time in hh:mm:ss format
            log_entry="$timestamp $1"  # Prepend the timestamp to the log entry
            echo "$log_entry" >> "$log_file"  # Append the log entry to the log file
        }  

        if [[ $lmsnsr_enabled == "true" ]]
            then
                lm_sensors=$(sensors -j)
        fi
        cpu_load=$(vmstat 1 2 | tail -1 | awk '{printf "%.2f\n", 100 - $15}')  #(mpstat 1 1 | awk 'END {print 100 - $NF}')
        memory_used=$(free -m | grep Mem | awk '{print $3}')
        iowait=$(mpstat 1 1 | grep -A 1 "all" | tail -n 1 | awk '{print $6}')

        source "$script_path/bin/component-fetch.conf"  
        sleep .5s

        if [[ $lmsnsr_enabled == "true" ]]
            then
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/lm_sensors" -m "$lm_sensors"
        fi
        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/cpu_load" -m "$cpu_load"
        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/memory_used" -m "$memory_used"
        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/iowait" -m "$iowait"

        source "$script_path/bin/component-post.conf"  

        if [[ $app_tui == "true" ]]
            then
                add_log_entry "cpu-load: $cpu_load% | memory used: "$memory_used"Mb | I/O-Wait: $iowait%"
        fi
        sleep $components_freq
    done&
)&
pids+=($!)
 

# NET monitoring loop
(

    while :; do
        log_file="k93sys.log"        
        add_log_entry() {
            timestamp=$(date +"%H:%M:%S")  # Get current time in hh:mm:ss format
            log_entry="$timestamp $1"  # Prepend the timestamp to the log entry
            echo "$log_entry" >> "$log_file"  # Append the log entry to the log file
        }


        if [[ $nic_1_enabled == "true" ]]
            then
                nic_1_in=$(ifstat -i $nic_1_interface $net_monitor_freq 1 | awk 'NR==3 {print $1}' | awk '{print $1 * 8 / 1000}')
                nic_2_in=$(ifstat -i $nic_1_interface $net_monitor_freq 1 | awk 'NR==3 {print $2}' | awk '{print $1 * 8 / 1000}')
        fi

        if [[ $nic_2_enabled == "true" ]]
            then
                nic_2_in=$(ifstat -i $nic_2_interface $net_monitor_freq 1 | awk 'NR==3 {print $1}' | awk '{print $1 * 8 / 1000}')
                nic_2_out=$(ifstat -i $nic_2_interface $net_monitor_freq 1 | awk 'NR==3 {print $2}' | awk '{print $1 * 8 / 1000}')
        fi

        if [[ $nic_3_enabled == "true" ]]
            then
                nic_3_in=$(ifstat -i $nic_3_interface $net_monitor_freq 1 | awk 'NR==3 {print $1}' | awk '{print $1 * 8 / 1000}')
                nic_3_out=$(ifstat -i $nic_3_interface $net_monitor_freq 1 | awk 'NR==3 {print $2}' | awk '{print $1 * 8 / 1000}')
        fi

        if [[ $nic_4_enabled == "true" ]]
            then
                nic_4_in=$(ifstat -i $nic_4_interface $net_monitor_freq 1 | awk 'NR==3 {print $1}' | awk '{print $1 * 8 / 1000}')
                nic_4_out=$(ifstat -i $nic_4_interface $net_monitor_freq 1 | awk 'NR==3 {print $2}' | awk '{print $1 * 8 / 1000}')
        fi

        if [[ $nic_5_enabled == "true" ]]
            then
                nic_5_in=$(ifstat -i $nic_5_interface $net_monitor_freq 1 | awk 'NR==3 {print $1}' | awk '{print $1 * 8 / 1000}')
                nic_5_out=$(ifstat -i $nic_5_interface $net_monitor_freq 1 | awk 'NR==3 {print $2}' | awk '{print $1 * 8 / 1000}')
        fi


        source "$script_path/bin/net-fetch.conf"  
        sleep .5s


        if [[ $nic_1_enabled == "true" ]]
            then
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/nic_1_in" -m "$nic_1_in"
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/nic_1_out" -m "$nic_1_out"
        fi

        if [[ $nic_2_enabled == "true" ]]
            then
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/nic_2_in" -m "$nic_2_in"
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/nic_2_out" -m "$nic_2_out"
        fi

        if [[ $nic_3_enabled == "true" ]]
            then
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/nic_3_in" -m "$nic_3_in"
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/nic_3_out" -m "$nic_3_out"
        fi

        if [[ $nic_4_enabled == "true" ]]
            then
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/nic_4_in" -m "$nic_4_in"
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/nic_4_out" -m "$nic_4_out"
        fi

        if [[ $nic_5_enabled == "true" ]]
            then
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/nic_5_in" -m "$nic_5_in"
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/nic_5_out" -m "$nic_5_out"
        fi



        source "$script_path/bin/net-post.conf"  
        
        if [[ $app_tui == "true" ]]
            then        
                add_log_entry "Network-interface data sent!"
        fi
        sleep $net_monitor_freq
    done&

)&
pids+=($!)

# HDD info loop 
(
    while :; do
        log_file="k93sys.log"        
        add_log_entry() {
            timestamp=$(date +"%H:%M:%S")  # Get current time in hh:mm:ss format
            log_entry="$timestamp $1"  # Prepend the timestamp to the log entry
            echo "$log_entry" >> "$log_file"  # Append the log entry to the log file
        }    

        if [[ $hddmon_enabled == "true" ]]
            then
                # storage
                storage_used_space_gb=$(df /mnt/storage --output=used | tail -n 1 | awk '{print $1/1024/1024}')
                storage_free_space_gb=$(df /mnt/storage --output=avail | tail -n 1 | awk '{print $1/1024/1024}')
                storage_total_space_gb=$(echo "$storage_used_space_gb + $storage_free_space_gb" | bc)

                if [[ $hddmon_1_enabled == "true" ]]
                    then
                        hddmon_1_used_space_gb=$(df $hddmon_1_path --output=used | tail -n 1 | awk '{print $1/1024/1024}')
                        hddmon_1_free_space_gb=$(df $hddmon_1_path --output=avail | tail -n 1 | awk '{print $1/1024/1024}')
                        hddmon_1_total_space_gb=$(echo "$hddmon_1_used_space_gb + $hddmon_1_free_space_gb" | bc)
                        hddmon_1_model=$(smartctl -i "/dev/$hddmon_1_device" | grep 'Device Model' | awk -F': ' '{print $2}' | xargs)
                        hddmon_1_rpm=$(smartctl -i "/dev/$hddmon_1_device" | grep 'Rotation Rate' | awk -F': ' '{print $2}' | xargs)
                        hddmon_1_serial=$(smartctl -i "/dev/$hddmon_1_device" | grep 'Serial Number' | awk -F': ' '{print $2}' | xargs)
                        hddmon_1_model="$hddmon_1_model $hddmon_1_rpm - SN:$hddmon_1_serial"
                        hddmon_1_smart_errors=$(smartctl -A "/dev/$hddmon_1_device" | grep -i 'Reallocated_Sector_Ct\|Current_Pending_Sector\|Offline_Uncorrectable' | awk '{sum += $10} END {print sum}')
                fi

                if [[ $hddmon_2_enabled == "true" ]]
                    then
                        hddmon_2_used_space_gb=$(df $hddmon_2_path --output=used | tail -n 1 | awk '{print $1/1024/1024}')
                        hddmon_2_free_space_gb=$(df $hddmon_2_path --output=avail | tail -n 1 | awk '{print $1/1024/1024}')
                        hddmon_2_total_space_gb=$(echo "$hddmon_2_used_space_gb + $hddmon_2_free_space_gb" | bc)
                        hddmon_2_model=$(smartctl -i "/dev/$hddmon_2_device" | grep 'Device Model' | awk -F': ' '{print $2}' | xargs)
                        hddmon_2_rpm=$(smartctl -i "/dev/$hddmon_2_device" | grep 'Rotation Rate' | awk -F': ' '{print $2}' | xargs)
                        hddmon_2_serial=$(smartctl -i "/dev/$hddmon_2_device" | grep 'Serial Number' | awk -F': ' '{print $2}' | xargs)
                        hddmon_2_model="$hddmon_2_model $hddmon_2_rpm - SN:$hddmon_2_serial"
                        hddmon_2_smart_errors=$(smartctl -A "/dev/$hddmon_2_device" | grep -i 'Reallocated_Sector_Ct\|Current_Pending_Sector\|Offline_Uncorrectable' | awk '{sum += $10} END {print sum}')
                fi

                if [[ $hddmon_3_enabled == "true" ]]
                    then
                        hddmon_3_used_space_gb=$(df $hddmon_3_path --output=used | tail -n 1 | awk '{print $1/1024/1024}')
                        hddmon_3_free_space_gb=$(df $hddmon_3_path --output=avail | tail -n 1 | awk '{print $1/1024/1024}')
                        hddmon_3_total_space_gb=$(echo "$hddmon_3_used_space_gb + $hddmon_3_free_space_gb" | bc)
                        hddmon_3_model=$(smartctl -i "/dev/$hddmon_3_device" | grep 'Device Model' | awk -F': ' '{print $2}' | xargs)
                        hddmon_3_rpm=$(smartctl -i "/dev/$hddmon_3_device" | grep 'Rotation Rate' | awk -F': ' '{print $2}' | xargs)
                        hddmon_3_serial=$(smartctl -i "/dev/$hddmon_3_device" | grep 'Serial Number' | awk -F': ' '{print $2}' | xargs)
                        hddmon_3_model="$hddmon_3_model $hddmon_3_rpm - SN:$hddmon_3_serial"
                        hddmon_3_smart_errors=$(smartctl -A "/dev/$hddmon_3_device" | grep -i 'Reallocated_Sector_Ct\|Current_Pending_Sector\|Offline_Uncorrectable' | awk '{sum += $10} END {print sum}')
                fi

                if [[ $hddmon_4_enabled == "true" ]]
                    then
                        hddmon_4_used_space_gb=$(df $hddmon_4_path --output=used | tail -n 1 | awk '{print $1/1024/1024}')
                        hddmon_4_free_space_gb=$(df $hddmon_4_path --output=avail | tail -n 1 | awk '{print $1/1024/1024}')
                        hddmon_4_total_space_gb=$(echo "$hddmon_4_used_space_gb + $hddmon_4_free_space_gb" | bc)
                        hddmon_4_model=$(smartctl -i "/dev/$hddmon_4_device" | grep 'Device Model' | awk -F': ' '{print $2}' | xargs)
                        hddmon_4_rpm=$(smartctl -i "/dev/$hddmon_4_device" | grep 'Rotation Rate' | awk -F': ' '{print $2}' | xargs)
                        hddmon_4_serial=$(smartctl -i "/dev/$hddmon_4_device" | grep 'Serial Number' | awk -F': ' '{print $2}' | xargs)
                        hddmon_4_model="$hddmon_4_model $hddmon_4_rpm - SN:$hddmon_4_serial"
                        hddmon_4_smart_errors=$(smartctl -A "/dev/$hddmon_4_device" | grep -i 'Reallocated_Sector_Ct\|Current_Pending_Sector\|Offline_Uncorrectable' | awk '{sum += $10} END {print sum}')
                fi

                if [[ $hddmon_5_enabled == "true" ]]
                    then
                        hddmon_5_used_space_gb=$(df $hddmon_5_path --output=used | tail -n 1 | awk '{print $1/1024/1024}')
                        hddmon_5_free_space_gb=$(df $hddmon_5_path --output=avail | tail -n 1 | awk '{print $1/1024/1024}')
                        hddmon_5_total_space_gb=$(echo "$hddmon_5_used_space_gb + $hddmon_5_free_space_gb" | bc)
                        hddmon_5_model=$(smartctl -i "/dev/$hddmon_5_device" | grep 'Device Model' | awk -F': ' '{print $2}' | xargs)
                        hddmon_5_rpm=$(smartctl -i "/dev/$hddmon_5_device" | grep 'Rotation Rate' | awk -F': ' '{print $2}' | xargs)
                        hddmon_5_serial=$(smartctl -i "/dev/$hddmon_5_device" | grep 'Serial Number' | awk -F': ' '{print $2}' | xargs)
                        hddmon_5_model="$hddmon_5_model $hddmon_5_rpm - SN:$hddmon_5_serial"
                        hddmon_5_smart_errors=$(smartctl -A "/dev/$hddmon_5_device" | grep -i 'Reallocated_Sector_Ct\|Current_Pending_Sector\|Offline_Uncorrectable' | awk '{sum += $10} END {print sum}')
                fi
        fi

        source "$script_path/bin/hdd-fetch.conf"  
        sleep .5s

        if [[ $hddmon_enabled == "true" ]]
            then
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/storage_reads" -m "$storage_reads"
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/storage_writes" -m "$storage_writes"
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/storage_used_space" -m "$storage_used_space_gb"
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/storage_free_space" -m "$storage_free_space_gb"
                mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/storage_total_space" -m "$storage_total_space_gb"
                if [[ $hddmon_1_enabled == "true" ]]
                    then
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_1_used_space" -m "$hddmon_1_used_space_gb"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_1_free_space" -m "$hddmon_1_free_space_gb"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_1_total_space" -m "$hddmon_1_total_space_gb"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_1_model" -m "$hddmon_1_model"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_1_smart_errors" -m "$hddmon_1_smart_errors"        
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_2_model" -m "$hddmon_2_model"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_2_smart_errors" -m "$hddmon_2_smart_errors"
                fi

                if [[ $hddmon_2_enabled == "true" ]]
                    then        
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_2_used_space" -m "$hddmon_2_used_space_gb"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_2_free_space" -m "$hddmon_2_free_space_gb"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_2_total_space" -m "$hddmon_2_total_space_gb"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_2_model" -m "$hddmon_2_model"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_2_smart_errors" -m "$hddmon_2_smart_errors"
                fi

                if [[ $hddmon_3_enabled == "true" ]]
                    then  
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_3_used_space" -m "$hddmon_3_used_space_gb"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_3_free_space" -m "$hddmon_3_free_space_gb"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_3_total_space" -m "$hddmon_3_total_space_gb"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_3_model" -m "$hddmon_3_model"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_3_smart_errors" -m "$hddmon_3_smart_errors"
                fi

                if [[ $hddmon_4_enabled == "true" ]]
                    then  
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_4_used_space" -m "$hddmon_4_used_space_gb"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_4_free_space" -m "$hddmon_4_free_space_gb"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_4_total_space" -m "$hddmon_4_total_space_gb"     
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_4_model" -m "$hddmon_4_model"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_4_smart_errors" -m "$hddmon_4_smart_errors"
                fi

                if [[ $hddmon_5_enabled == "true" ]]
                    then  
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_5_used_space" -m "$hddmon_5_used_space_gb"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_5_free_space" -m "$hddmon_5_free_space_gb"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_5_total_space" -m "$hddmon_5_total_space_gb"     
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_5_model" -m "$hddmon_5_model"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_5_smart_errors" -m "$hddmon_5_smart_errors"
                fi
        fi

        source "$script_path/bin/hdd-post.conf"      
        if [[ $app_tui == "true" ]]
            then
                add_log_entry "Storage: Reads: $storage_reads MB/s, Writes: $storage_writes MB/s | (HDD1)$hdd1_model: Reads: $hdd1_reads MB/s, Writes: $hdd1_writes MB/s | (HDD2)$hdd2_model: Reads: $hdd2_reads MB/s, Writes: $hdd2_writes MB/s | (HDD3)$hdd3_model: Reads: $hdd3_reads MB/s, Writes: $hdd3_writes MB/s | (HDD4)$hdd4_model: Reads: $hdd4_reads MB/s, Writes: $hdd4_writes MB/s"
        fi
        sleep $storage_freq
    done&
)&
pids+=($!)

# HDD monitoring loop 
(
    while :; do
        log_file="k93sys.log"        
        add_log_entry() {
            timestamp=$(date +"%H:%M:%S")  # Get current time in hh:mm:ss format
            log_entry="$timestamp $1"  # Prepend the timestamp to the log entry
            echo "$log_entry" >> "$log_file"  # Append the log entry to the log file
        }    



        if [[ $hddmon_enabled == "true" ]]
            then
                if [[ $hddmon_1_enabled == "true" ]]
                    then    
                        # hddmon_1 Configuration (e.g., /dev/sda)
                        hddmon_1_reads=$(iostat -d -m 1 2 | grep $hddmon_1_device | tail -n 1 | awk '{print $3}')
                        hddmon_1_writes=$(iostat -d -m 1 2 | grep $hddmon_1_device | tail -n 1 | awk '{print $4}')
                fi

                if [[ $hddmon_2_enabled == "true" ]]
                    then          
                        # hddmon_2 Configuration (e.g., /dev/sdb)
                        hddmon_2_reads=$(iostat -d -m 1 2 | grep $hddmon_2_device | tail -n 1 | awk '{print $3}')
                        hddmon_2_writes=$(iostat -d -m 1 2 | grep $hddmon_2_device | tail -n 1 | awk '{print $4}')
                fi

                if [[ $hddmon_3_enabled == "true" ]]
                    then       
                        # hddmon_3 Configuration (e.g., /dev/sdc)
                        hddmon_3_reads=$(iostat -d -m 1 2 | grep $hddmon_3_device | tail -n 1 | awk '{print $3}')
                        hddmon_3_writes=$(iostat -d -m 1 2 | grep $hddmon_3_device | tail -n 1 | awk '{print $4}')
                fi

                if [[ $hddmon_4_enabled == "true" ]]
                    then       
                        # hddmon_4 Configuration (e.g., /dev/sdd)
                        hddmon_4_reads=$(iostat -d -m 1 2 | grep $hddmon_4_device | tail -n 1 | awk '{print $3}')
                        hddmon_4_writes=$(iostat -d -m 1 2 | grep $hddmon_4_device | tail -n 1 | awk '{print $4}')
                fi

                if [[ $hddmon_5_enabled == "true" ]]
                    then       
                        # hddmon_5 Configuration (e.g., /dev/sdd)
                        hddmon_5_reads=$(iostat -d -m 1 2 | grep $hddmon_5_device | tail -n 1 | awk '{print $3}')
                        hddmon_5_writes=$(iostat -d -m 1 2 | grep $hddmon_5_device | tail -n 1 | awk '{print $4}')        
                fi
        fi

        source "$script_path/bin/hddrw-fetch.conf"  
        sleep .5s
        if [[ $hddmon_enabled == "true" ]]
            then

                if [[ $hddmon_1_enabled == "true" ]]
                    then  
                # Publish hddmon_1 Data
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_1_reads" -m "$hddmon_1_reads"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_1_writes" -m "$hddmon_1_writes"
                fi

                if [[ $hddmon_2_enabled == "true" ]]
                    then  
                # Publish hddmon_2 Data
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_2_reads" -m "$hddmon_2_reads"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_2_writes" -m "$hddmon_2_writes"
                fi

                if [[ $hddmon_3_enabled == "true" ]]
                    then  
                # Publish hddmon_3 Data
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_3_reads" -m "$hddmon_3_reads"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_3_writes" -m "$hddmon_3_writes"
                fi

                if [[ $hddmon_4_enabled == "true" ]]
                    then  
                # Publish hddmon_4 Data
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_4_reads" -m "$hddmon_4_reads"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_4_writes" -m "$hddmon_4_writes"
                fi

                if [[ $hddmon_5_enabled == "true" ]]
                    then  
                # Publish hddmon_5 Data
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_5_reads" -m "$hddmon_5_reads"
                        mosquitto_pub -h $server -u $mqtt_user -P $mqtt_pwd -t "$mqtt_topic/$mqtt_device/hddmon_5_writes" -m "$hddmon_5_writes"
                fi

        fi        
        source "$script_path/bin/hddrw-post.conf"     
        if [[ $app_tui == "true" ]]
            then
                add_log_entry "System Monitoring complete"
        fi
              #  add_log_entry "System Monitoring complete"
        
        sleep $storage_rw_freq
    done&
)&
pids+=($!)

# Wait for all background processes
wait
