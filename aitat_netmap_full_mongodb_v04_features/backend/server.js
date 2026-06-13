require("dotenv").config();
const express = require("express");
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const cors = require("cors");
const morgan = require("morgan");

const app = express();
const PORT = process.env.PORT || 4000;
const JWT_SECRET = process.env.JWT_SECRET || "dev_secret";

app.use(
  cors({
    origin: true,
    credentials: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  }),
);
app.options("*", cors({ origin: true, credentials: true }));
app.use(express.json({ limit: "2mb" }));
app.use(morgan("dev"));

const userSchema = new mongoose.Schema(
  {
    name: { type: String, default: "" },
    email: { type: String, unique: true, required: true, lowercase: true },
    passwordHash: { type: String, required: true },
    role: {
      type: String,
      enum: ["admin", "engineer", "viewer"],
      default: "viewer",
    },
  },
  { timestamps: true },
);

const deviceSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    type: { type: String, default: "pc" },
    room: { type: String, default: "Open-space" },
    ip: { type: String, default: "" },
    mac: { type: String, default: "" },
    status: {
      type: String,
      enum: ["online", "warning", "offline", "maintenance"],
      default: "online",
    },
    load: { type: Number, default: 25 },
    latency: { type: Number, default: 8 },
    uptime: { type: Number, default: 99 },
    description: { type: String, default: "" },
    connectedTo: [{ type: String }],
  },
  { timestamps: true },
);

const incidentSchema = new mongoose.Schema(
  {
    title: { type: String, required: true },
    deviceId: { type: mongoose.Schema.Types.ObjectId, ref: "Device" },
    deviceName: { type: String, default: "" },
    severity: {
      type: String,
      enum: ["low", "medium", "high", "critical"],
      default: "medium",
    },
    description: { type: String, default: "" },
    status: { type: String, enum: ["active", "resolved"], default: "active" },
    notes: [
      {
        text: String,
        actor: String,
        createdAt: { type: Date, default: Date.now },
      },
    ],
    resolvedAt: Date,
    resolvedBy: String,
  },
  { timestamps: true },
);

const eventSchema = new mongoose.Schema(
  {
    message: { type: String, required: true },
    type: { type: String, default: "info" },
    deviceId: { type: mongoose.Schema.Types.ObjectId, ref: "Device" },
    deviceName: { type: String, default: "" },
    actor: { type: String, default: "Система" },
  },
  { timestamps: true },
);

const User = mongoose.model("User", userSchema);
const Device = mongoose.model("Device", deviceSchema);
const Incident = mongoose.model("Incident", incidentSchema);
const EventLog = mongoose.model("EventLog", eventSchema);

function sign(user) {
  return jwt.sign(
    {
      id: user._id.toString(),
      email: user.email,
      role: user.role,
      name: user.name,
    },
    JWT_SECRET,
    { expiresIn: "7d" },
  );
}
function actorName(user) {
  if (!user) return "Система";
  if (user.name && user.name.trim()) return user.name.trim();
  if (user.role === "admin") return "Администратор";
  if (user.role === "engineer") return "Инженер";
  return "Пользователь";
}
async function auth(req, res, next) {
  const header = req.headers.authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!token)
    return res.status(401).json({ message: "Нет токена авторизации" });
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    const user = await User.findById(payload.id);
    if (!user)
      return res.status(401).json({ message: "Пользователь не найден" });
    req.user = user;
    next();
  } catch (_) {
    res.status(401).json({ message: "Недействительный токен" });
  }
}
function canWrite(req, res, next) {
  if (req.user.role === "admin" || req.user.role === "engineer") return next();
  return res.status(403).json({ message: "Недостаточно прав" });
}
function rnd(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}
function clamp(n, min = 0, max = 100) {
  const x = Number(n);
  if (!Number.isFinite(x)) return min;
  return Math.max(min, Math.min(max, Math.round(x)));
}
function statusType(status) {
  if (status === "offline") return "danger";
  if (status === "warning") return "warning";
  if (status === "maintenance") return "info";
  return "success";
}
function defaultLoad(type) {
  const t = String(type || "").toLowerCase();
  if (t === "server") return rnd(48, 88);
  if (t === "switch") return rnd(38, 76);
  if (t === "router") return rnd(42, 84);
  if (t === "access_point" || t === "ap") return rnd(32, 72);
  if (t === "printer") return rnd(8, 28);
  return rnd(18, 52);
}
function impactByType(type) {
  const t = String(type || "").toLowerCase();
  if (t === "server") return 10;
  if (t === "router") return 8;
  if (t === "switch") return 6;
  if (t === "access_point" || t === "ap") return 6;
  if (t === "printer") return 2;
  return 4;
}
function severityFromDevice(device) {
  if (!device) return "medium";
  if (device.status === "offline") return "critical";
  if (device.status === "warning" || device.load >= 80) return "high";
  if (device.status === "maintenance") return "medium";
  return "low";
}
async function addEvent(message, options = {}) {
  return EventLog.create({
    message,
    type: options.type || "info",
    deviceId: options.deviceId,
    deviceName: options.deviceName || "",
    actor: options.actor || "Система",
  });
}
async function coreDevice() {
  return Device.findOne({
    $or: [{ name: /core switch/i }, { name: /core/i }, { type: "switch" }],
  }).sort({ createdAt: 1 });
}
async function chooseConnectionFor(deviceData) {
  const type = String(deviceData.type || "").toLowerCase();
  const room = deviceData.room || "Open-space";
  const core = await coreDevice();
  if (!core) return [];
  if (["switch", "router", "server"].includes(type))
    return [core._id.toString()];
  const roomNode = await Device.findOne({
    room,
    type: { $in: ["switch", "router", "access_point", "ap"] },
  }).sort({ createdAt: 1 });
  return [(roomNode || core)._id.toString()];
}
async function applyImpact(device, sign = 1) {
  const ids = Array.isArray(device.connectedTo) ? device.connectedTo : [];
  if (ids.length === 0) return;
  const delta = sign * impactByType(device.type);
  for (const id of ids) {
    const target = await Device.findById(id);
    if (target && target._id.toString() !== device._id.toString()) {
      target.load = clamp((target.load || 0) + delta, 0, 100);
      if (target.load >= 80 && target.status === "online")
        target.status = "warning";
      await target.save();
    }
  }
}

async function seed() {
  if ((await User.countDocuments()) === 0) {
    const pass = await bcrypt.hash("123456", 10);
    await User.create([
      {
        name: "Администратор",
        email: "admin@aitat.local",
        passwordHash: pass,
        role: "admin",
      },
      {
        name: "Инженер",
        email: "engineer@aitat.local",
        passwordHash: pass,
        role: "engineer",
      },
      {
        name: "Наблюдатель",
        email: "viewer@aitat.local",
        passwordHash: pass,
        role: "viewer",
      },
    ]);
  }
  if ((await Device.countDocuments()) === 0) {
    const devices = await Device.create([
      {
        name: "Core Switch-01",
        type: "switch",
        room: "Серверная",
        ip: "192.168.1.2",
        status: "online",
        load: 57,
        latency: 3,
        uptime: 99,
        description: "Центральный коммутатор",
      },
      {
        name: "Core Router-01",
        type: "router",
        room: "Серверная",
        ip: "192.168.1.1",
        status: "warning",
        load: 76,
        latency: 18,
        uptime: 96,
        description: "Маршрутизатор периметра",
      },
      {
        name: "Srv-CRM-01",
        type: "server",
        room: "Серверная",
        ip: "192.168.1.10",
        status: "warning",
        load: 87,
        latency: 7,
        uptime: 99,
        description: "Сервер CRM",
      },
      {
        name: "AP-OpenSpace-012",
        type: "access_point",
        room: "Open-space",
        ip: "192.168.2.12",
        status: "warning",
        load: 72,
        latency: 31,
        uptime: 94,
        description: "Точка доступа open-space",
      },
      {
        name: "AP-Meeting-01",
        type: "access_point",
        room: "Переговорная",
        ip: "192.168.2.22",
        status: "online",
        load: 38,
        latency: 9,
        uptime: 99,
        description: "Wi-Fi переговорной",
      },
      {
        name: "Printer-Office-01",
        type: "printer",
        room: "Зона печати",
        ip: "192.168.4.10",
        status: "offline",
        load: 12,
        latency: 0,
        uptime: 87,
        description: "МФУ отдела",
      },
      {
        name: "WS-CEO-01",
        type: "pc",
        room: "Кабинет CEO",
        ip: "192.168.5.21",
        status: "online",
        load: 31,
        latency: 12,
        uptime: 99,
        description: "Рабочая станция",
      },
      {
        name: "WS-Open-15",
        type: "pc",
        room: "Open-space",
        ip: "192.168.3.15",
        status: "online",
        load: 42,
        latency: 10,
        uptime: 99,
        description: "Рабочая станция",
      },
    ]);
    const core = devices[0];
    for (const d of devices) {
      if (
        d._id.toString() !== core._id.toString() &&
        d.connectedTo.length === 0
      ) {
        d.connectedTo = [core._id.toString()];
        await d.save();
      }
    }
    await Incident.create([
      {
        title: "Проблема: AP-OpenSpace-012",
        deviceId: devices[3]._id,
        deviceName: devices[3].name,
        severity: "high",
        description: "Высокая нагрузка и нестабильный отклик.",
        status: "active",
      },
      {
        title: "Принтер недоступен",
        deviceId: devices[5]._id,
        deviceName: devices[5].name,
        severity: "medium",
        description: "Устройство не отвечает на запросы.",
        status: "active",
      },
      {
        title: "Проблема: Core Router-01",
        deviceId: devices[1]._id,
        deviceName: devices[1].name,
        severity: "critical",
        description: "Повышенная нагрузка маршрутизатора.",
        status: "active",
      },
    ]);
    await addEvent("Система инициализирована, созданы демо-данные", {
      type: "system",
    });
    await addEvent("Обнаружена высокая нагрузка AP-OpenSpace-012", {
      type: "warning",
      deviceId: devices[3]._id,
      deviceName: devices[3].name,
    });
    await addEvent("Printer-Office-01 перешёл в состояние offline", {
      type: "danger",
      deviceId: devices[5]._id,
      deviceName: devices[5].name,
    });
  }
}

app.get("/api/health", (req, res) =>
  res.json({
    ok: true,
    service: "AITAT NetMap API",
    db: mongoose.connection.name,
    time: new Date().toISOString(),
  }),
);

app.post("/api/auth/register", async (req, res) => {
  const { name, email, password } = req.body;
  if (!email || !password)
    return res.status(400).json({ message: "Укажите email и пароль" });
  const exists = await User.findOne({ email: String(email).toLowerCase() });
  if (exists)
    return res.status(409).json({ message: "Пользователь уже существует" });
  const passwordHash = await bcrypt.hash(password, 10);
  const user = await User.create({
    name: name || "Пользователь",
    email: String(email).toLowerCase(),
    passwordHash,
    role: "engineer",
  });
  await addEvent(`Создан пользователь: ${user.name}`, {
    actor: actorName(user),
    type: "system",
  });
  res.json({
    token: sign(user),
    user: { id: user._id, name: user.name, email: user.email, role: user.role },
  });
});

app.post("/api/auth/login", async (req, res) => {
  const { email, password } = req.body;
  const user = await User.findOne({ email: String(email || "").toLowerCase() });
  if (!user)
    return res.status(401).json({ message: "Неверный email или пароль" });
  const ok = await bcrypt.compare(String(password || ""), user.passwordHash);
  if (!ok)
    return res.status(401).json({ message: "Неверный email или пароль" });
  await addEvent(`Вход в систему: ${actorName(user)}`, {
    actor: actorName(user),
    type: "info",
  });
  res.json({
    token: sign(user),
    user: { id: user._id, name: user.name, email: user.email, role: user.role },
  });
});

app.get("/api/me", auth, (req, res) =>
  res.json({
    user: {
      id: req.user._id,
      name: req.user.name,
      email: req.user.email,
      role: req.user.role,
    },
  }),
);

app.get("/api/devices", auth, async (req, res) => {
  const devices = await Device.find().sort({ room: 1, name: 1 });
  res.json({ devices });
});

app.post("/api/devices", auth, canWrite, async (req, res) => {
  const body = req.body || {};
  if (!body.name)
    return res.status(400).json({ message: "Введите название устройства" });
  const data = {
    name: body.name,
    type: body.type || "pc",
    room: body.room || "Open-space",
    ip: body.ip || "",
    mac: body.mac || "",
    status: body.status || "online",
    load:
      body.load === undefined
        ? defaultLoad(body.type || "pc")
        : clamp(body.load),
    latency:
      body.latency === undefined ? rnd(4, 45) : clamp(body.latency, 0, 999),
    uptime: body.uptime === undefined ? rnd(93, 99) : clamp(body.uptime),
    description: body.description || "",
  };
  data.connectedTo = await chooseConnectionFor(data);
  const device = await Device.create(data);
  await applyImpact(device, 1);
  await addEvent(
    `Добавлено устройство: ${device.name}. Нагрузка назначена ${device.load}%`,
    {
      actor: actorName(req.user),
      type: "success",
      deviceId: device._id,
      deviceName: device.name,
    },
  );
  res.status(201).json({ device });
});

app.patch("/api/devices/:id", auth, canWrite, async (req, res) => {
  const device = await Device.findById(req.params.id);
  if (!device)
    return res.status(404).json({ message: "Устройство не найдено" });
  const beforeStatus = device.status;
  const fields = ["name", "type", "room", "ip", "mac", "status", "description"];
  for (const f of fields)
    if (req.body[f] !== undefined) device[f] = req.body[f];
  if (req.body.load !== undefined) device.load = clamp(req.body.load);
  if (req.body.latency !== undefined)
    device.latency = clamp(req.body.latency, 0, 999);
  device.connectedTo = await chooseConnectionFor(device);
  await device.save();
  if (beforeStatus !== device.status) {
    await addEvent(`Статус изменён: ${device.name} → ${device.status}`, {
      actor: actorName(req.user),
      type: statusType(device.status),
      deviceId: device._id,
      deviceName: device.name,
    });
  } else {
    await addEvent(`Обновлены данные устройства: ${device.name}`, {
      actor: actorName(req.user),
      type: "info",
      deviceId: device._id,
      deviceName: device.name,
    });
  }
  res.json({ device });
});

app.delete("/api/devices/:id", auth, canWrite, async (req, res) => {
  const device = await Device.findById(req.params.id);
  if (!device)
    return res.status(404).json({ message: "Устройство не найдено" });
  await applyImpact(device, -1);
  await device.deleteOne();
  await addEvent(
    `Удалено устройство: ${device.name}. Нагрузка связанных узлов уменьшена`,
    { actor: actorName(req.user), type: "danger", deviceName: device.name },
  );
  res.json({ ok: true });
});

app.post("/api/devices/:id/ping", auth, async (req, res) => {
  try {
    const device = await Device.findById(req.params.id);

    if (!device) {
      return res.status(404).json({ message: "Устройство не найдено" });
    }

    const wasOffline = device.status === "offline";

    // Простая демо-логика ping:
    // если устройство уже offline — считаем, что оно недоступно;
    // иначе в 90% случаев доступно, в 10% — временно не отвечает.
    const isReachable = !wasOffline && Math.random() > 0.1;

    if (isReachable) {
      const latency = Math.floor(Math.random() * 85) + 5; // 5–90 ms
      const loadDelta = Math.floor(Math.random() * 15) - 6; // -6..+8

      device.latency = latency;
      device.load = Math.max(
        5,
        Math.min(99, Number(device.load || 25) + loadDelta),
      );

      if (device.status !== "maintenance") {
        if (latency > 70 || device.load > 80) {
          device.status = "warning";
        } else {
          device.status = "online";
        }
      }

      await device.save();

      await addEvent(
        `Выполнен ping: ${device.name}. Устройство доступно. Задержка ${device.latency} ms, нагрузка ${device.load}%.`,
        {
          actor: actorName(req.user),
          type: "info",
          deviceId: device._id,
          deviceName: device.name,
        },
      );

      return res.json({
        ok: true,
        reachable: true,
        message: `Устройство доступно. Задержка ${device.latency} ms.`,
        latency: device.latency,
        load: device.load,
        status: device.status,
        device,
      });
    }

    device.latency = 0;
    device.status = "offline";
    await device.save();

    await addEvent(`Выполнен ping: ${device.name}. Устройство недоступно.`, {
      actor: actorName(req.user),
      type: "danger",
      deviceId: device._id,
      deviceName: device.name,
    });

    return res.json({
      ok: false,
      reachable: false,
      message: "Устройство недоступно.",
      latency: 0,
      load: device.load,
      status: device.status,
      device,
    });
  } catch (err) {
    return res.status(500).json({
      message: "Ошибка ping-проверки",
      error: err.message,
    });
  }
});

app.get("/api/incidents", auth, async (req, res) => {
  const incidents = await Incident.find().sort({ status: 1, createdAt: -1 });
  res.json({ incidents });
});

app.post("/api/incidents", auth, canWrite, async (req, res) => {
  const body = req.body || {};
  const device = body.deviceId ? await Device.findById(body.deviceId) : null;
  const incident = await Incident.create({
    title: body.title || `Инцидент: ${device ? device.name : "без устройства"}`,
    deviceId: device ? device._id : undefined,
    deviceName: device ? device.name : body.deviceName || "",
    severity: body.severity || severityFromDevice(device),
    description:
      body.description || "Описание причины и действий для устранения.",
    status: "active",
  });
  await addEvent(`Создан инцидент: ${incident.title}`, {
    actor: actorName(req.user),
    type: "warning",
    deviceId: device ? device._id : undefined,
    deviceName: incident.deviceName,
  });
  res.status(201).json({ incident });
});

app.patch("/api/incidents/:id/comment", auth, canWrite, async (req, res) => {
  const incident = await Incident.findById(req.params.id);
  if (!incident) return res.status(404).json({ message: "Инцидент не найден" });
  const text = String(req.body.comment || "").trim();
  if (!text) return res.status(400).json({ message: "Введите комментарий" });
  incident.notes.push({
    text,
    actor: actorName(req.user),
    createdAt: new Date(),
  });
  await incident.save();
  await addEvent(
    `Добавлен комментарий к инциденту: ${incident.title}. Статус остался активным`,
    {
      actor: actorName(req.user),
      type: "info",
      deviceId: incident.deviceId,
      deviceName: incident.deviceName,
    },
  );
  res.json({ incident });
});

app.patch("/api/incidents/:id/resolve", auth, canWrite, async (req, res) => {
  const incident = await Incident.findById(req.params.id);
  if (!incident) return res.status(404).json({ message: "Инцидент не найден" });
  if (incident.status !== "resolved") {
    incident.status = "resolved";
    incident.resolvedAt = new Date();
    incident.resolvedBy = actorName(req.user);
    await incident.save();
    await addEvent(`Инцидент решён: ${incident.title}`, {
      actor: actorName(req.user),
      type: "success",
      deviceId: incident.deviceId,
      deviceName: incident.deviceName,
    });
  }
  res.json({ incident });
});

app.get("/api/events", auth, async (req, res) => {
  const events = await EventLog.find().sort({ createdAt: -1 }).limit(120);
  res.json({ events });
});

app.get("/api/overview", auth, async (req, res) => {
  const devices = await Device.find();
  const activeIncidents = await Incident.countDocuments({ status: "active" });
  const total = devices.length;
  const online = devices.filter((d) => d.status === "online").length;
  const problems = devices.filter(
    (d) => d.status === "warning" || d.status === "offline",
  ).length;
  const maintenance = devices.filter((d) => d.status === "maintenance").length;
  const avgLoad = total
    ? Math.round(devices.reduce((sum, d) => sum + (d.load || 0), 0) / total)
    : 0;
  const topLoad = devices
    .slice()
    .sort((a, b) => (b.load || 0) - (a.load || 0))
    .slice(0, 6);
  res.json({
    total,
    online,
    problems,
    maintenance,
    activeIncidents,
    avgLoad,
    topLoad,
  });
});

mongoose
  .connect(
    process.env.MONGO_URI || "mongodb://127.0.0.1:27017/aitat_netmap_demo",
  )
  .then(async () => {
    console.log("MongoDB connected:", mongoose.connection.name);
    await seed();
    app.listen(PORT, () =>
      console.log(`AITAT NetMap API running on http://localhost:${PORT}`),
    );
  })
  .catch((err) => {
    console.error("MongoDB connection error:", err.message);
    process.exit(1);
  });
