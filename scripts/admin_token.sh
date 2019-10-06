ADMIN_USER=`kubectl -n kube-system get secret | grep admin-user | awk '{print $1}'`
ADMIN_TOKEN=`kubectl -n kube-system describe secret $ADMIN_USER|grep token:|awk '{print $2}'`
echo "$ADMIN_TOKEN"
