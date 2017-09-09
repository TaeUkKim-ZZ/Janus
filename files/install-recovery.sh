#!/system/bin/sh

# This is part of the provision optimizer.
# based on SteelHeart eXtreme Engine V4
#
# All shell schript code is developed by SteelHeart(Kihan Park).
# Second Edited edited by Vista(@NexusRoi).
# Final Edit with test by SteelHeart(@SteelHeart_Hug)
#
# Do not, Do not edit.

# Remount all partitions
busybox mount -o remount,noatime,nodev /system 
busybox mount -o remount,noatime,noauto_da_alloc,nosuid,nodev /data 
busybox mount -o remount,noatime,nosuid,nodev /cache

#for Debug Code
echo "1" > /system/etc/provision_already

# Scheduler tweaks
echo "4000000" > /proc/sys/kernel/sched_min_granularity_ns
echo "8000000" > /proc/sys/kernel/sched_latency_ns
echo "1600000" > /proc/sys/kernel/sched_wakeup_granularity_ns

# Memory Tweaks
echo "1" > /proc/sys/vm/oom_kill_allocating_task
echo "0" > /proc/sys/vm/panic_on_oom
echo "1" > /proc/sys/kernel/panic_on_oops
echo "0" > /proc/sys/kernel/panic

# Play bootsound if it can
stagefright -a -o $(cat /data/provision/bootsound_path)


# zipalign system data applications
if [ -e /data/provision/zipalign ] then
  LOG_FILE=/data/zipalign.log;
  ZIPALIGNDB=/data/zipalign.db;
  
  if [ -e $LOG_FILE ]; then
	rm $LOG_FILE;
  fi;
  
  if [ ! -f $ZIPALIGNDB ]; then
	touch $ZIPALIGNDB;
  fi;
  echo "Starting FV Automatic ZipAlign $( date +"%m-%d-%Y %H:%M:%S" )" | tee -a $LOG_FILE;
  for DIR in /system/app /data/app; do
	cd $DIR;
	for APK in *.apk; do
		if [ $APK -ot $ZIPALIGNDB ] && [ $(grep "$DIR/$APK" $ZIPALIGNDB|wc -l) -gt 0 ]; then
			echo "Already checked: $DIR/$APK" | tee -a $LOG_FILE;
		else
			ZIPCHECK=`/system/xbin/zipalign -c -v 4 $APK | grep FAILED | wc -l`;
		fi;
		if [ $ZIPCHECK == "1" ]; then 
			echo "Now aligning: $DIR/$APK" | tee -a $LOG_FILE;
			/system/xbin/zipalign -v -f 4 $APK /sdcard/download/$APK;
			busybox mount -o rw,remount /system;
			cp -f -p /sdcard/download/$APK $APK;
			grep "$DIR/$APK" $ZIPALIGNDB > /dev/null || echo $DIR/$APK >> $ZIPALIGNDB;
		else
			echo "Already aligned: $DIR/$APK" | tee -a $LOG_FILE;
			grep "$DIR/$APK" $ZIPALIGNDB > /dev/null || echo $DIR/$APK >> $ZIPALIGNDB;
		fi;
	done;
  done;
  busybox mount -o ro,remount /system;
  touch $ZIPALIGNDB;
  echo "Automatic ZipAlign finished at $( date +"%m-%d-%Y %H:%M:%S" )" | tee -a $LOG_FILE;
  busybox rm -rf /data/provision/zipalign
fi

#vm config change

if [ -e /sys/module/lowmemorykiller/parameters/adj ]; then
	echo "0,0,0,0,0,0" > /sys/module/lowmemorykiller/parameters/adj
fi

if [ -e /proc/sys/vm/vfs_cache_pressure ]; then
	echo "70" > /proc/sys/vm/vfs_cache_pressure
fi

if [ -e /proc/sys/vm/dirty_expire_centisecs ]; then
	echo "3000" > /proc/sys/vm/dirty_expire_centisecs
fi

if [ -e /proc/sys/vm/dirty_writeback_centisecs ]; then
	echo "500" > /proc/sys/vm/dirty_writeback_centisecs
fi

if [ -e /proc/sys/vm/dirty_ratio ]; then
	echo "15" > /proc/sys/vm/dirty_ratio
fi

if [ -e /proc/sys/vm/dirty_background_ratio ]; then
	echo "3" > /proc/sys/vm/dirty_background_ratio
fi

sync;
echo 3 > /proc/sys/vm/drop_caches;
sleep 1;
echo 0 > /proc/sys/vm/drop_caches;
echo "Caches are dropped!";
echo 200000 > /proc/sys/kernel/sched_min_granularity_ns;
echo 600000 > /proc/sys/kernel/sched_latency_ns;
echo 100000 > /proc/sys/kernel/sched_wakeup_granularity_ns;
renice -20 16

# Set io scheduler tweaks for mmc
if [ -e /data/provision/scheduler_deadline ] then
	echo "deadline" > /sys/block/mmcblk0/queue/scheduler
	echo "0" > /sys/block/mmcblk0/queue/rotational
	echo "2048" > /sys/block/mmcblk0/queue/nr_requests
	echo ${READ_AHEAD_KB} > /sys/block/mmcblk0/queue/read_ahead_kb
	echo "deadline" > /sys/block/mmcblk1/queue/scheduler
	echo "0" > /sys/block/mmcblk1/queue/rotational
	echo "2048" > /sys/block/mmcblk1/queue/nr_requests
	echo ${READ_AHEAD_KB} > /sys/block/mmcblk1/queue/read_ahead_kb
	for i in \ `find /data -iname "*.db"` do \ sqlite3 
		$i 'VACUUM;' 
	done
fi

# One-time tweaks to apply on every boot
STL=`ls -d /sys/block/stl*`
BML=`ls -d /sys/block/bml*`
MMC=`ls -d /sys/block/mmc*`

# Tweak deadline io scheduler
for i in $STL $BML $MMC $TFSR; do
echo 0 > $i/queue/rotational
echo 1 > $i/queue/iosched/low_latency
echo 1 > $i/queue/iosched/back_seek_penalty
echo 1000000000 > $i/queue/iosched/back_seek_max
echo 3 > $i/queue/iosched/slice_idle
echo 16 > $i/queue/iosched/quantum
echo 1 > $i/queue/iosched/fifo_batch
echo deadline > $i/queue/scheduler
done

# Tweak kernel VM management
echo 0 > /proc/sys/vm/swappiness
echo 10 > /proc/sys/vm/dirty_ratio
echo 4096 > /proc/sys/vm/min_free_kbytes

# Tweak kernel scheduler, less aggressive settings
echo 20000000 > /proc/sys/kernel/sched_latency_ns
echo 2500000 > /proc/sys/kernel/sched_wakeup_granularity_ns
echo 1000000 > /proc/sys/kernel/sched_min_granularity_ns

# Virtual Memory script by SteelHeart
if [ -e /data/provision/vms ]; then 
	chmod 644 /sys/module/lowmemorykiller/parameters/minfree
	echo "0,0,0,0,0,0" > /sys/module/lowmemorykiller/parameters/minfree
	dd if=/dev/zero of=/sdcard/swapfile bs=$(cat /data/provision/vms_size) count=524288
	mkswap /sdcard/swapfile
	swapon /sdcard/swapfile
	echo "100" > /proc/sys/vm/swappiness
fi

# Set tendency of kernel to swap to minimum, since swap isn't used anyway.
# (swap = move portions of RAM data to disk partition or file, to free-up RAM)
# (a value of 0 means "do not swap unless out of free RAM", a value of 100 means "swap whenever possible")
# (the default is 60 which is okay for normal Linux installations)

# Lower the amount of unwritten write cache to reduce lags when a huge write is required.

echo "10" "/proc/sys/vm" "/dirty_ratio"
echo "4096" "/proc/sys/vm" "/min_free_kbytes"

# Increase tendency of kernel to keep block-cache to help with slower RFS filesystem.

# DEF 100
echo "1000" "/proc/sys/vm" "/vfs_cache_pressure"

# Increase the write flush timeouts to save some battery life.
# Make the task scheduler more 'fair' when multiple tasks are running,
# which improves user-interface and application responsiveness.

echo "20000000" "/proc/sys/kernel" "/sched_latency_ns"
echo "2000000" "/proc/sys/kernel" "/sched_wakeup_granularity_ns"
echo "1000000" "/proc/sys/kernel" "/sched_min_granularity_ns"

sync

# This apply a tweaked deadline scheduler to all RFS partitions.
for i in /sys/block/*
do
DEF noop anticipatory deadline cfq [bfq]
echo deadline > $i/queue/scheduler

echo 4 > $i/queue/iosched/writes_starved
echo 1 > $i/queue/iosched/fifo_batch
echo 256 > $i/queue/nr_requests

# CMPLX TH3ORY

# File System Mounts
#
busybox mount -o remount,noatime,nodiratime,discard,noauto_da_alloc,nosuid,nodev,data=writeback,barrier=0 -t auto /
busybox mount -o remount,noatime,nodiratime,discard,noauto_da_alloc,nosuid,nodev,data=writeback,barrier=0 -t auto /dev
busybox mount -o remount,noatime,nodiratime,discard,noauto_da_alloc,nosuid,nodev,data=writeback,barrier=0 -t auto /proc
busybox mount -o remount,noatime,nodiratime,discard,noauto_da_alloc,nosuid,nodev,data=writeback,barrier=0 -t auto /sys
busybox mount -o remount,noatime,nodiratime,discard,noauto_da_alloc,nosuid,nodev,data=writeback,barrier=0 -t auto /system
busybox mount -o remount,noatime,nodiratime,discard,noauto_da_alloc,nosuid,nodev,data=writeback,barrier=0 -t auto /data
busybox mount -o remount,noatime,nodiratime,discard,noauto_da_alloc,nosuid,nodev,data=writeback,barrier=0 -t auto /data/data
busybox mount -o remount,noatime,nodiratime,discard,noauto_da_alloc,nosuid,nodev,data=writeback,barrier=0 -t auto /cache
busybox mount -o remount,noatime,nodiratime,discard,noauto_da_alloc,nosuid,nodev,data=writeback,barrier=0 -t auto /acct
busybox mount -o remount,noatime,nodiratime,discard,noauto_da_alloc,nosuid,nodev,data=writeback,barrier=0 -t auto /dev/pts
busybox mount -o remount,noatime,nodiratime,discard,noauto_da_alloc,nosuid,nodev,data=writeback,barrier=0 -t auto /dev/cpuctl
busybox mount -o remount,noatime,nodiratime,discard,noauto_da_alloc,nosuid,nodev,data=writeback,barrier=0 -t auto /mnt/asec
busybox mount -o remount,noatime,nodiratime,discard,noauto_da_alloc,nosuid,nodev,data=writeback,barrier=0 -t auto /mnt/obb
busybox mount -o remount,noatime,nodiratime,discard,noauto_da_alloc,nosuid,nodev,data=writeback,barrier=0 -t auto /mnt/sdcard

# enable sysctl tweaks
#
sysctl -p /system/etc/sysctl.conf

# Start crond
#
echo "root:x:0:0::data/cron:/system/xbin/bash" > /system/etc/passwd
mount -o remount,rw rootfs /
ln -s /system/xbin /xbin
mount -o remount,ro rootfs /
timezone=`date +%z`
if [ $timezone = "-0800" ]; then
TZ=PST8PDT
elif [ $timezone = "-0700" ]; then
TZ=MST7MDT
elif [ $timezone = "-0600" ]; then
TZ=CST6CDT
elif [ $timezone = "-0500" ]; then
TZ=EST5EDT
else TZ=EST5EDT
fi
export TZ
crond -c /data/cron

#Deep Sleep
#
echo "5" > /sys/devices/system/cpu/cpu0/cpufreq/deepsleep_cpulevel
echo "2" > /sys/devices/system/cpu/cpu0/cpufreq/deepsleep_buslevel

#Core
echo "3" > /sys/module/cpuidle/parameters/enable_mask

#Scaling
echo "1" > /sys/devices/system/cpu/sched_mc_power_savings
echo "0" > /sys/devices/system/cpu/cpu0/cpufreq/smooth_target
echo "0" > /sys/devices/system/cpu/cpu0/cpufreq/smooth_offset
echo "0" > /sys/devices/system/cpu/cpu0/cpufreq/smooth_step

# Optimize Vm
if [ -e /proc/sys/vm/vfs_cache_pressure ]; then
echo "10" > /proc/sys/vm/vfs_cache_pressure
fi

if [ -e /proc/sys/vm/dirty_expire_centisecs ]; then
echo "500" > /proc/sys/vm/dirty_expire_centisecs
fi

if [ -e /proc/sys/vm/dirty_writeback_centisecs ]; then
echo "1000" > /proc/sys/vm/dirty_writeback_centisecs
fi

if [ -e /proc/sys/vm/dirty_ratio ]; then
echo "90" > /proc/sys/vm/dirty_ratio
fi

if [ -e /proc/sys/vm/dirty_background_ratio ]; then
echo "45" > /proc/sys/vm/dirty_background_ratio
fi

if [ -f "\$i" ]; then
sync;
echo "cfq" > \$i;
fi

# File System
busybox mount -o remount,noatime,barrier=0,nobh /cache
echo "1536,2304,4096,17920,19456,33472" > /sys/module/lowmemorykiller/parameters/minfree

#HyperTh3ory
#
rm -f /cache/*.apk
rm -f /cache/*.tmp
rm -f /data/dalvik-cache/*.apk
rm -f /data/dalvik-cache/*.tmp
busybox mount -o remount,rw,noatime,noauto_da_alloc,nodiratime,barrier=0,nobh /system
busybox mount -o remount,noatime,noauto_da_alloc,nodiratime,nodev,barrier=0,nobh /data
busybox mount -o remount,noatime,noauto_da_all
sysctl -w vm.overcommit_memory=1
sysctl -w vm.page-cluster=3
sysctl -w vm.drop_caches=3
busybox rm -f /data/system/userbehavior.db
busybox chmod 400 /data/system/usagestats/
busybox chmod 400 /data/system/appusagestats/

# Vibration
echo "1550" > /sys/vibe/pwmduty

# normalized sleeper
mount -t debugfs none /sys/kernel/debug
echo NO_NORMALIZED_SLEEPER > /sys/kernel/debug/sched_features
echo "0,1,2,4,6,15" > /sys/module/lowmemorykiller/parameters/adj
echo "2560,4096,6144,10752,11264,13312" > /sys/module/lowmemorykiller/parameters/minfree
echo "70" > /proc/sys/vm/vfs_cache_pressure
echo "3000" > /proc/sys/vm/dirty_expire_centisecs
echo "500" > /proc/sys/vm/dirty_writeback_centisecs
echo "15" > /proc/sys/vm/dirty_ratio
echo "3" > /proc/sys/vm/dirty_background_ratio

done