# Proyecto llamado de enfermeras

#### -> Instalar
###### Para instalar las dependencias del proyecto, ejecuta:
```bash
npm i
```
#### Ejecutar
###### Para ejecutar el proyecto en modo desarrollo, utiliza:
```bash
npm run dev
```


#### -> Rutas Informacion

###### Las siguientes rutas están disponibles para interactuar con la API de atencio de camas:

###### GET


###### POST


#### -> Docker

```bash
docker build -t atencion_camillas_backend_v2 .
```

```bash
docker run -p 4000:4000 -d --network red_camas --name atencion_camillas_backend atencion_camillas_backend_v2
```