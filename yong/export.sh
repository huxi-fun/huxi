export GTK_IM_MODULE=yong
export GTK3_IM_MODULE=yong
export QT_IM_MODULE=yong
export QT5_IM_MODULE=yong
export XMODIFIERS="@im=yong"
export XIM="yong"
export XIM_PROGRAM="/usr/bin/yong"
export XIM_ARGS=""
eval "$(dbus-launch --sh-syntax --exit-with-session)"
yong -d
