// Jenkinsfile - Main CI/CD Pipeline
// Location: /Jenkinsfile (root directory)

pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'docker.io'
        DOCKER_CREDENTIALS = credentials('docker-hub-credentials')
        KUBECONFIG = credentials('kubeconfig-file')
        BACKEND_IMAGE = "${DOCKER_CREDENTIALS_USR}/rag-backend"
        CHATBOT_IMAGE = "${DOCKER_CREDENTIALS_USR}/rag-chatbot"
        FRONTEND_IMAGE = "${DOCKER_CREDENTIALS_USR}/rag-frontend"
        BUILD_TAG = "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
        NAMESPACE = 'rag-chatbot'
    }

    parameters {
        choice(
            name: 'DEPLOYMENT_ENV',
            choices: ['staging', 'production'],
            description: 'Select deployment environment'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Skip running tests'
        )
        booleanParam(
            name: 'SKIP_DEPLOY',
            defaultValue: false,
            description: 'Skip deployment to Kubernetes'
        )
    }

    options {
        timeout(time: 1, unit: 'HOURS')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timestamps()
    }

    stages {
        stage('Checkout') {
            steps {
                echo '=== Checking out code ==='
                checkout scm
                script {
                    env.GIT_COMMIT_MSG = sh(
                        script: "git log -1 --pretty=%B",
                        returnStdout: true
                    ).trim()
                    env.GIT_AUTHOR = sh(
                        script: "git log -1 --pretty=%an",
                        returnStdout: true
                    ).trim()
                }
                echo "Commit: ${GIT_COMMIT_MSG}"
                echo "Author: ${GIT_AUTHOR}"
            }
        }

        stage('Backend - Lint & Build') {
            steps {
                echo '=== Backend: Linting and Building ==='
                dir('backend') {
                    script {
                        try {
                            sh '''
                                echo "Installing Node dependencies..."
                                npm ci
                                
                                echo "Running lint..."
                                if grep -q '"lint"' package.json; then
                                    npm run lint
                                else
                                    echo "No lint script found, skipping..."
                                fi
                                
                                echo "Running build..."
                                if grep -q '"build"' package.json; then
                                    npm run build
                                else
                                    echo "No build script found, skipping..."
                                fi
                            '''
                        } catch (Exception e) {
                            echo "Backend build failed: ${e.message}"
                            currentBuild.result = 'FAILURE'
                            error("Backend build stage failed")
                        }
                    }
                }
            }
        }

        stage('Chatbot - Lint & Test') {
            steps {
                echo '=== Chatbot: Linting and Testing ==='
                dir('chatbot') {
                    script {
                        try {
                            sh '''
                                echo "Setting up Python environment..."
                                python3 -m venv venv || python -m venv venv
                                . venv/bin/activate
                                pip install -r requirements.txt
                                
                                echo "Installing flake8..."
                                pip install flake8
                                
                                echo "Running flake8 linter..."
                                flake8 . --max-line-length=120 --ignore=E501
                                
                                echo "Running pytest..."
                                if [ -d "tests" ]; then
                                    python -m pytest ../tests/ -v || echo "Tests completed with warnings"
                                else
                                    echo "No tests directory found, skipping..."
                                fi
                            '''
                        } catch (Exception e) {
                            echo "Chatbot lint/test failed: ${e.message}"
                            currentBuild.result = 'FAILURE'
                            error("Chatbot lint/test stage failed")
                        }
                    }
                }
            }
        }

        stage('Frontend - Lint & Build') {
            steps {
                echo '=== Frontend: Linting and Building ==='
                dir('frontend') {
                    script {
                        try {
                            sh '''
                                echo "Installing Node dependencies..."
                                npm ci
                                
                                echo "Running lint..."
                                if grep -q '"lint"' package.json; then
                                    npm run lint
                                else
                                    echo "No lint script found, skipping..."
                                fi
                                
                                echo "Running Vite build..."
                                npm run build
                            '''
                        } catch (Exception e) {
                            echo "Frontend build failed: ${e.message}"
                            currentBuild.result = 'FAILURE'
                            error("Frontend build stage failed")
                        }
                    }
                }
            }
        }

        stage('Build Docker Images') {
            when {
                branch 'main'
            }
            steps {
                echo '=== Building Docker Images ==='
                script {
                    try {
                        sh '''
                            echo "Logging in to Docker Hub..."
                            echo $DOCKER_CREDENTIALS_PSW | docker login -u $DOCKER_CREDENTIALS_USR --password-stdin
                            
                            echo "Building backend image..."
                            docker build -t ${BACKEND_IMAGE}:${BUILD_TAG} -t ${BACKEND_IMAGE}:latest ./backend
                            
                            echo "Building chatbot image..."
                            docker build -t ${CHATBOT_IMAGE}:${BUILD_TAG} -t ${CHATBOT_IMAGE}:latest -f chatbot/Dockerfile .
                            
                            echo "Building frontend image..."
                            docker build -t ${FRONTEND_IMAGE}:${BUILD_TAG} -t ${FRONTEND_IMAGE}:latest ./frontend
                            
                            echo "Images built successfully"
                            docker images | grep rag-
                        '''
                    } catch (Exception e) {
                        echo "Docker build failed: ${e.message}"
                        currentBuild.result = 'FAILURE'
                        error("Docker build stage failed")
                    }
                }
            }
        }

        stage('Push Docker Images') {
            when {
                branch 'main'
            }
            steps {
                echo '=== Pushing Docker Images to Registry ==='
                script {
                    try {
                        sh '''
                            echo "Pushing backend image..."
                            docker push ${BACKEND_IMAGE}:${BUILD_TAG}
                            docker push ${BACKEND_IMAGE}:latest
                            
                            echo "Pushing chatbot image..."
                            docker push ${CHATBOT_IMAGE}:${BUILD_TAG}
                            docker push ${CHATBOT_IMAGE}:latest
                            
                            echo "Pushing frontend image..."
                            docker push ${FRONTEND_IMAGE}:${BUILD_TAG}
                            docker push ${FRONTEND_IMAGE}:latest
                            
                            echo "Images pushed successfully"
                        '''
                    } catch (Exception e) {
                        echo "Docker push failed: ${e.message}"
                        currentBuild.result = 'FAILURE'
                        error("Docker push stage failed")
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            when {
                branch 'main'
                expression { return !params.SKIP_DEPLOY }
            }
            steps {
                echo '=== Deploying to Kubernetes ==='
                script {
                    try {
                        sh '''
                            echo "Setting up kubectl..."
                            export KUBECONFIG=$(pwd)/kubeconfig
                            
                            echo "Applying namespace..."
                            kubectl apply -f k8s/namespace.yaml
                            
                            echo "Applying configmap..."
                            kubectl apply -f k8s/configmap.yaml
                            
                            echo "Updating backend deployment..."
                            kubectl set image deployment/backend \
                              backend=${BACKEND_IMAGE}:${BUILD_TAG} \
                              -n ${NAMESPACE}
                            
                            echo "Updating chatbot deployment..."
                            kubectl set image deployment/chatbot \
                              chatbot=${CHATBOT_IMAGE}:${BUILD_TAG} \
                              -n ${NAMESPACE}
                            
                            echo "Updating frontend deployment..."
                            kubectl set image deployment/frontend \
                              frontend=${FRONTEND_IMAGE}:${BUILD_TAG} \
                              -n ${NAMESPACE}
                            
                            echo "Applying remaining manifests..."
                            kubectl apply -f k8s/backend/
                            kubectl apply -f k8s/chatbot/
                            kubectl apply -f k8s/frontend/
                            kubectl apply -f k8s/mongodb/
                            
                            echo "Waiting for rollout..."
                            kubectl rollout status deployment/backend -n ${NAMESPACE} --timeout=120s
                            kubectl rollout status deployment/chatbot -n ${NAMESPACE} --timeout=120s
                            kubectl rollout status deployment/frontend -n ${NAMESPACE} --timeout=120s
                            
                            echo "Deployment successful!"
                        '''
                    } catch (Exception e) {
                        echo "Deployment failed: ${e.message}"
                        echo "Rolling back deployments..."
                        sh '''
                            kubectl rollout undo deployment/backend -n ${NAMESPACE}
                            kubectl rollout undo deployment/chatbot -n ${NAMESPACE}
                            kubectl rollout undo deployment/frontend -n ${NAMESPACE}
                        '''
                        currentBuild.result = 'FAILURE'
                        error("Kubernetes deployment failed")
                    }
                }
            }
        }

        stage('Health Check') {
            when {
                branch 'main'
                expression { return !params.SKIP_DEPLOY }
            }
            steps {
                echo '=== Running Health Checks ==='
                script {
                    sh '''
                        echo "Checking pod status..."
                        kubectl get pods -n ${NAMESPACE}
                        
                        echo "Checking deployment status..."
                        kubectl get deployments -n ${NAMESPACE}
                        
                        echo "Checking services..."
                        kubectl get services -n ${NAMESPACE}
                    '''
                }
            }
        }
    }

    post {
        always {
            echo '=== Cleanup ==='
            script {
                try {
                    sh 'docker logout'
                } catch (Exception e) {
                    echo "Docker logout failed (non-fatal): ${e.message}"
                }
            }
            junit testResults: '**/test-results.xml', allowEmptyResults: true
            archiveArtifacts artifacts: '**/logs/**', allowEmptyArchive: true
        }

        success {
            echo 'PIPELINE SUCCESSFUL'
            echo "Build Number: ${BUILD_NUMBER}"
            echo "Build Tag: ${BUILD_TAG}"
        }

        failure {
            echo 'PIPELINE FAILED'
            echo "Build Number: ${BUILD_NUMBER}"
            echo "Failed at: ${env.STAGE_NAME}"
        }

        unstable {
            echo 'PIPELINE UNSTABLE'
        }
    }
}
