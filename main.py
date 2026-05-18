import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import pymysql
from pymysql.constants import CLIENT
from dbutils.pooled_db import PooledDB

app = FastAPI(title="FastAPI Data Backend")

# 1. Configuración de CORS (Esencial para que el Dashboard pueda hacerle peticiones sin bloqueos)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # En producción puedes cambiar el "*" por la IP de tu dashboard
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 2. Extracción de variables de entorno inyectadas por Docker
DB_HOST = os.getenv("DB_HOST")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_NAME = os.getenv("DB_NAME")

# 3. Creación del Pool de Conexiones (Idéntico a tu Node.js)
pool = PooledDB(
    creator=pymysql,
    maxconnections=10,          # connectionLimit: 10
    blocking=True,              # waitForConnections: true
    host=DB_HOST,
    user=DB_USER,
    password=DB_PASSWORD,
    database=DB_NAME,
    client_flag=CLIENT.MULTI_STATEMENTS, # multipleStatements: true
    cursorclass=pymysql.cursors.DictCursor
)

def get_db_connection():
    return pool.connection()

# 4. El Endpoint que tu Dashboard de Dash va a consumir
@app.get("/run-query")
def ejecutar_query():
    ruta_sql = "query.sql"
    
    if not os.path.exists(ruta_sql):
        raise HTTPException(status_code=500, detail="El archivo query.sql no existe.")
    
    try:
        with open(ruta_sql, "r", encoding="utf-8") as archivo:
            sql_script = archivo.read()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error leyendo SQL: {str(e)}")

    # Toma una conexión del pool, ejecuta, y la libera automáticamente
    conexion = get_db_connection()
    try:
        with conexion.cursor() as cursor:
            cursor.execute(sql_script)
            resultados = cursor.fetchall()
            
        return {"status": "success3", "data": resultados}
        
    except pymysql.MySQLError as e:
        raise HTTPException(status_code=500, detail=f"Error de base de datos: {str(e)}")
    finally:
        conexion.close() # Devuelve la conexión a la fila