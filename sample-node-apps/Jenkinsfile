pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command: ["/busybox/sh", "-c"]
    args: ["sleep 9999999"]
    volumeMounts:
    - name: workspace-volume
      mountPath: /home/jenkins/agent
  - name: kubectl
    image: alpine/k8s:1.28.3
    command: ["sleep"]
    args: ["9999999"]
    volumeMounts:
    - name: workspace-volume
      mountPath: /home/jenkins/agent
  volumes:
  - name: workspace-volume
    emptyDir: {}
'''
        }
    }
    
    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
    }
    
    stages {
        stage('Checkout App Code') {
            steps {
                git branch: 'main', url: 'https://github.com/workytip/sample-node-apps.git'
            }
        }
        
        stage('Build with Kaniko') {
            steps {
                container('kaniko') {
                    script {
                        withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                            sh '''
                            mkdir -p /kaniko/.docker
                            echo "{\\"auths\\":{\\"https://index.docker.io/v1/\\":{\\"auth\\":\\"$(echo -n $DOCKER_USER:$DOCKER_PASS | base64 | tr -d '\\n')\\"}}}" > /kaniko/.docker/config.json
                            
                            /kaniko/executor --context=/home/jenkins/agent/workspace/node-apps-pipeline/app1 --destination=workytip/node-app1:latest
                            /kaniko/executor --context=/home/jenkins/agent/workspace/node-apps-pipeline/app2 --destination=workytip/node-app2:latest
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    script {
                        sh '''
                        cd /home/jenkins/agent/workspace/node-apps-pipeline
                        git clone https://github.com/workytip/k8s-applications.git
                        
                        echo "=== Applying Kubernetes manifests recursively ==="
                        kubectl apply -f k8s-applications/2-applications/ -R
                        
                        echo "=== Waiting for resources to be created ==="
                        sleep 30
                        
                        echo "=== Checking deployments in app namespace ==="
                        kubectl get deployments -n app
                        
                        echo "=== Restarting deployments to use new images ==="
                        kubectl rollout restart deployment/app1 -n app
                        kubectl rollout restart deployment/app2 -n app
                        
                        echo "=== Waiting for rollout to complete ==="
                        kubectl rollout status deployment/app1 -n app --timeout=300s
                        kubectl rollout status deployment/app2 -n app --timeout=300s
                        
                        echo "=== Final status ==="
                        kubectl get pods -n app
                        kubectl get services -n app
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo "=== Pipeline completed ==="
        }
        success {
            echo "✅ Pipeline completed successfully! Applications deployed to EKS."
        }
        failure {
            echo "❌ Pipeline failed. Check the logs above for details."
        }
    }
}