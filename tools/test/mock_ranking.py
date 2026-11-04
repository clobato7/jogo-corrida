"""Servidor falso do ranking para testes locais (porta 8799).
Rode: python3 tools/test/mock_ranking.py
E abra o jogo com RANKING_URL=http://127.0.0.1:8799/rest/v1/rpc/ (só funciona em build de debug).
"""
import json, http.server
rows=[{"id":1,"player_name":"Pedrinho","time_ms":39000,"car":"f1_vermelho"},{"id":2,"player_name":"Pedrinho","time_ms":45000,"car":"caminhao_azul"},{"id":3,"player_name":"Vovó","time_ms":38500,"car":"caminhao_azul"}]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def do_POST(self):
        body=json.loads(self.rfile.read(int(self.headers['Content-Length'])) or b'{}')
        if self.path.endswith('submit_time'):
            rows.append({"id":99,"player_name":body['p_name'],"time_ms":body['p_time_ms'],"car":body['p_car']})
            out={"id":99,"position":3,"personal_best":False,"counted":True}
        else:
            base=sorted(rows,key=lambda r:r['time_ms']); out=[dict(r,pos=i+1) for i,r in enumerate(base)]
        b=json.dumps(out).encode(); self.send_response(200); self.send_header('Content-Type','application/json'); self.send_header('Content-Length',str(len(b))); self.end_headers(); self.wfile.write(b)
http.server.HTTPServer(('127.0.0.1',8799),H).serve_forever()
