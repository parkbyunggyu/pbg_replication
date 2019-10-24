rm -rf ~/sshconn.sh
touch ~/sshconn.sh
cat > ~/sshconn.sh <<EOFF
rm -rf ~/.ssh
ssh-keygen -t rsa
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh/*
EOFF
cd ~
bash ~/sshconn.sh
scp ~/sshconn.sh root@$1:~/
ssh -T root@$1 bash ~/sshconn.sh


scp root@$1:~/.ssh/authorized_keys ~/.ssh/temp.pub
cp ~/.ssh/temp.pub ~/.ssh/temp2.pub
cat ~/.ssh/authorized_keys >> ~/.ssh/temp2.pub
cat ~/.ssh/temp.pub >> ~/.ssh/authorized_keys
scp ~/.ssh/temp2.pub root@$1:~/.ssh/authorized_keys
rm -rf ~/temp.*

ssh $1 date
ssh -T root@$1 ssh `ifconfig eth0 |awk '{print $2}'|head -n +2|tail -n 1` date
