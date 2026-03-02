import os
import subprocess
import webbrowser
import http.server
import socketserver
import threading
import time
import sys

# Configurações
PORT = 8080
BUILD_PATH = os.path.join(os.getcwd(), "build", "web")
DIRECTORY = BUILD_PATH

def run_command(command):
    """Executa um comando no terminal e aguarda a finalização."""
    try:
        process = subprocess.Popen(command, shell=True)
        process.wait()
        return process.returncode == 0
    except Exception as e:
        print(f"Erro ao executar comando: {e}")
        return False

def build_totem():
    """Verifica se o build existe e reconstrói se necessário."""
    print("\n--- Verificação de Build ---")
    
    rebuild = "n"
    if os.path.exists(BUILD_PATH):
        rebuild = input("O build já existe. Deseja reconstruir para garantir que está atualizado? (s/n): ").lower()
    else:
        print("Build não encontrado. Iniciando build inicial...")
        rebuild = "s"

    if rebuild == "s":
        print("Executando: flutter build web --release...")
        # Tenta usar o script otimizado se estiver no Windows, caso contrário usa o flutter padrão
        if os.name == 'nt' and os.path.exists("build_web_optimized.ps1"):
            success = run_command("powershell -ExecutionPolicy Bypass -File build_web_optimized.ps1")
        else:
            success = run_command("flutter build web --release")
        
        if not success:
            print("\n❌ Erro ao gerar o build do Flutter.")
            sys.exit(1)
    
    if not os.path.exists(BUILD_PATH):
        print(f"\n❌ Erro: A pasta {BUILD_PATH} não foi encontrada após o build.")
        sys.exit(1)

def start_server():
    """Inicia o servidor HTTP na pasta do build."""
    os.chdir(DIRECTORY)
    Handler = http.server.SimpleHTTPRequestHandler
    
    # Permite que o servidor seja reiniciado rapidamente sem erro de 'Address already in use'
    socketserver.TCPServer.allow_reuse_address = True
    
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        print(f"\n✅ Servidor rodando em: http://localhost:{PORT}")
        print(f"📁 Servindo arquivos de: {DIRECTORY}")
        print("    [Pressione Ctrl+C para encerrar]")
        
        # Abre o navegador após um curto delay para garantir que o servidor subiu
        threading.Timer(1.5, lambda: webbrowser.open(f"http://localhost:{PORT}")).start()
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\nEncerrando servidor...")
            httpd.shutdown()
            sys.exit(0)

if __name__ == "__main__":
    print("========================================")
    print("      TOTEM RELEASE RUNNER (PYTHON)     ")
    print("========================================")
    
    # 1. Preparar o build
    build_totem()
    
    # 2. Rodar o servidor
    start_server()
