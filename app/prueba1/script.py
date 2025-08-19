import xmlrpc.client
import base64
import os
from datetime import datetime

class OdooProjectDownloader:
    def __init__(self, url, db, username, password):
        self.url = url
        self.db = db
        self.username = username
        self.password = password

        # Autenticación
        self.common = xmlrpc.client.ServerProxy(f'{url}/xmlrpc/2/common')
        self.uid = self.common.authenticate(db, username, password, {})
        self.models = xmlrpc.client.ServerProxy(f'{url}/xmlrpc/2/object')

        if not self.uid:
            raise Exception("Error de autenticación")

        print(f"Logeo exitoso: {username}")

    def buscar_proyecto_por_folio(self, folio):

        try:
            campos_folio = ['name', 'code', 'reference', 'x_folio', 'folio']

            proyecto = None
            for campo in campos_folio:
                try:
                    proyectos = self.models.execute_kw(
                        self.db, self.uid, self.password,
                        'project.project', 'search_read',
                        [[('active', '=', True)]],
                        {'fields': ['id', 'name', campo] if campo != 'name' else ['id', 'name']}
                    )

                    for p in proyectos:
                        valor_campo = p.get(campo, '') or p.get('name', '')
                        if folio.lower() in str(valor_campo).lower():
                            proyecto = p
                            print(f"Encontrado: {p['name']} (ID: {p['id']})")
                            break

                    if proyecto:
                        break

                except Exception as e:
                    continue

            return proyecto

        except Exception as e:
            print(f"Error buscando proyecto: {e}")
            return None

    def obtener_etapas_proyecto(self, project_id):
        try:
            etapas = self.models.execute_kw(
                self.db, self.uid, self.password,
                'project.task.type', 'search_read',
                [[('project_ids', 'in', [project_id])]],
                {'fields': ['id', 'name', 'sequence']}
            )

            etapas = sorted(etapas, key=lambda x: x.get('sequence', 0))
            print(f"Etapas encontradas: {len(etapas)}")
            for etapa in etapas:
                print(f"  - {etapa['name']}")

            return etapas

        except Exception as e:
            print(f"Error obteniendo etapas: {e}")
            return []

    def obtener_tareas_proyecto(self, project_id):
        try:
            tareas = self.models.execute_kw(
                self.db, self.uid, self.password,
                'project.task', 'search_read',
                [[('project_id', '=', project_id), ('active', '=', True)]],
                {'fields': ['id', 'name', 'stage_id', 'sequence']}
            )

            print(f"Tareas encontradas: {len(tareas)}")
            return tareas

        except Exception as e:
            print(f"Error obteniendo tareas: {e}")
            return []

    def obtener_adjuntos(self, res_model, res_id):
        try:
            adjuntos = self.models.execute_kw(
                self.db, self.uid, self.password,
                'ir.attachment', 'search_read',
                [[('res_model', '=', res_model), ('res_id', '=', res_id)]],
                {'fields': ['id', 'name', 'datas', 'mimetype', 'file_size']}
            )

            return adjuntos

        except Exception as e:
            print(f"Error obteniendo adjuntos: {e}")
            return []

    def crear_estructura_carpetas(self, folio, etapas):
        carpeta_base = f"Proyecto_{folio}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

        if not os.path.exists(carpeta_base):
            os.makedirs(carpeta_base)

        carpeta_proyecto = os.path.join(carpeta_base, "00_Proyecto_Principal")
        if not os.path.exists(carpeta_proyecto):
            os.makedirs(carpeta_proyecto)

        carpetas_etapas = {}
        for i, etapa in enumerate(etapas, 1):
            nombre_carpeta = f"{i:02d}_{self.limpiar_nombre_archivo(etapa['name'])}"
            carpeta_etapa = os.path.join(carpeta_base, nombre_carpeta)
            if not os.path.exists(carpeta_etapa):
                os.makedirs(carpeta_etapa)
            carpetas_etapas[etapa['id']] = carpeta_etapa

        return carpeta_base, carpeta_proyecto, carpetas_etapas

    def limpiar_nombre_archivo(self, nombre):
        caracteres_invalidos = '<>:"/\|?*'
        for char in caracteres_invalidos:
            nombre = nombre.replace(char, '_')
        return nombre.strip()

    def descargar_archivo(self, adjunto, carpeta_destino):
        try:
            if not adjunto.get('datas'):
                print(f"  ⚠️  Archivo sin datos: {adjunto['name']}")
                return False

            nombre_archivo = self.limpiar_nombre_archivo(adjunto['name'])
            ruta_archivo = os.path.join(carpeta_destino, nombre_archivo)

            contador = 1
            ruta_original = ruta_archivo
            while os.path.exists(ruta_archivo):
                nombre_base, extension = os.path.splitext(ruta_original)
                ruta_archivo = f"{nombre_base}_{contador}{extension}"
                contador += 1

            datos_archivo = base64.b64decode(adjunto['datas'])
            with open(ruta_archivo, 'wb') as f:
                f.write(datos_archivo)

            tamaño_mb = len(datos_archivo) / (1024 * 1024)
            print(f"  ✅ Descargado: {nombre_archivo} ({tamaño_mb:.2f} MB)")
            return True

        except Exception as e:
            print(f"  ❌ Error descargando {adjunto['name']}: {e}")
            return False

    def descargar_archivos_proyecto(self, folio):
        print(f"\n🔍 Buscando proyecto con folio: {folio}")

        proyecto = self.buscar_proyecto_por_folio(folio)
        if not proyecto:
            print("❌ Folio no encontrado")
            return

        project_id = proyecto['id']

        print(f"\n📋 Obteniendo estructura del proyecto...")
        etapas = self.obtener_etapas_proyecto(project_id)
        tareas = self.obtener_tareas_proyecto(project_id)

        print(f"\n📁 Creando estructura de carpetas...")
        carpeta_base, carpeta_proyecto, carpetas_etapas = self.crear_estructura_carpetas(folio, etapas)

        total_archivos = 0
        archivos_descargados = 0

        print(f"\n📥 Descargando archivos del proyecto principal...")
        adjuntos_proyecto = self.obtener_adjuntos('project.project', project_id)
        total_archivos += len(adjuntos_proyecto)

        for adjunto in adjuntos_proyecto:
            if self.descargar_archivo(adjunto, carpeta_proyecto):
                archivos_descargados += 1

        tareas_por_etapa = {}
        for tarea in tareas:
            stage_id = tarea['stage_id'][0] if tarea['stage_id'] else None
            if stage_id not in tareas_por_etapa:
                tareas_por_etapa[stage_id] = []
            tareas_por_etapa[stage_id].append(tarea)

        for etapa in etapas:
            etapa_id = etapa['id']
            carpeta_etapa = carpetas_etapas[etapa_id]

            print(f"\n📥 Procesando etapa: {etapa['name']}")

            tareas_etapa = tareas_por_etapa.get(etapa_id, [])
            if not tareas_etapa:
                print("  📝 Sin tareas en esta etapa")
                continue

            for tarea in tareas_etapa:
                print(f"  📝 Procesando tarea: {tarea['name']}")

                # Crear subcarpeta para la tarea
                nombre_tarea = self.limpiar_nombre_archivo(tarea['name'])
                carpeta_tarea = os.path.join(carpeta_etapa, nombre_tarea)
                if not os.path.exists(carpeta_tarea):
                    os.makedirs(carpeta_tarea)

                # Obtener y descargar adjuntos de la tarea
                adjuntos_tarea = self.obtener_adjuntos('project.task', tarea['id'])
                total_archivos += len(adjuntos_tarea)

                if not adjuntos_tarea:
                    print("    📎 Sin archivos adjuntos")
                    continue

                for adjunto in adjuntos_tarea:
                    if self.descargar_archivo(adjunto, carpeta_tarea):
                        archivos_descargados += 1

        print(f"\n✅ Descarga completada!")
        print(f"📊 Resumen:")
        print(f"   - Archivos encontrados: {total_archivos}")
        print(f"   - Archivos descargados: {archivos_descargados}")
        print(f"   - Carpeta de destino: {carpeta_base}")

        return carpeta_base

def main():
    # Configuración de la conexión
    url = 'https://consultiva-control1.odoo.com'
    db = 'consultiva-control1'  
    username = 'zabdiel.ramirez@consultiva.mx'
    password = '2cc7b0bb692ac5268a39ba2bc24da1f797a01a35'

    try:
        # Crear instancia del descargador
        downloader = OdooProjectDownloader(url, db, username, password)

        # Solicitar folio al usuario
        folio = input("\n🔍 Ingresa el folio del proyecto: ").strip()

        if not folio:
            print("❌ Debes ingresar un folio")
            return

        # Descargar archivos
        downloader.descargar_archivos_proyecto(folio)

        


    except Exception as e:
        print(f"❌ Error general: {e}")

if __name__ == "__main__":
    main()
