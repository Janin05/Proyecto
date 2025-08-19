#Protocolo llama a Procedimiento Remoto (RPC)
import xmlrpc.client

#Datos de conexión auth.py
url = 'https://consultiva-control1.odoo.com'
db = 'consultiva-control1'
username = 'zabdiel.ramirez@consultiva.mx'
#password = '2cc7b0bb692ac5268a39ba2bc24da1f797a01a35' # asegúrate de que este token sea correcto y activo
password = 'Omegapocalipsis@7'

common = xmlrpc.client.ServerProxy(f'{url}/xmlrpc/2/common')
version = common.version()
print("Odoo versión:", version)

uid = common.authenticate(db, username, password, {})
if uid:
    print('Autenticado exitosamente. UID:', uid)
else:
    print('Autenticación fallida. Revisa token, usuario o permisos.')


