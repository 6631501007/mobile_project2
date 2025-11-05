const express = require('express');
const app = express();
const cors = require('cors');
const bcrypt = require('bcrypt');
const con = require('./db');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const saltRounds = 10;

// --- Multer Configuration (กำหนดค่าแค่ครั้งเดียว) ---
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, 'uploads/');
    },
    filename: function (req, file, cb) {
        // [แก้ไข] originalname (แก้ Typo)
        cb(null, Date.now() + path.extname(file.originalname));
    }
});
const upload = multer({ storage: storage });

// --- Serve Uploaded Images Statically (กำหนดค่าแค่ครั้งเดียว) ---
app.use('/uploads', express.static('uploads'));

/* POST /login */
app.post('/login', (req, res) => {
    console.log("--- Login Request Received ---");
    const { email, password } = req.body;
    console.log(`Email: ${email}, Pass: ${password ? '***' : 'empty'}`);
    if (!email || !password) {
        console.log("Login Error: Missing email or password");
        return res.status(400).json({ success: false, message: 'กรุณากรอกอีเมลและรหัสผ่าน' });
    }
    const sql = "SELECT user_id, email, full_name, role, password_hash FROM users WHERE email = ?";
    console.log("Executing SQL for login...");
    con.query(sql, [email], async function (err, results) {
        if (err) {
            console.error("Login Error: Database query failed:", err);
            return res.status(500).json({ success: false, message: 'Database server error' });
        }
        console.log("SQL Query completed. Results found:", results.length);
        if (results.length > 0) {
            const user = results[0];
            const storedHash = user.password_hash;
            try {
                console.log("Comparing password...");
                const match = await bcrypt.compare(password, storedHash);
                console.log("Password match result:", match);
                if (match) {
                    delete user.password_hash;
                    res.json({ success: true, user: user });
                } else {
                    console.log("Login Error: Password mismatch");
                    res.status(401).json({ success: false, message: 'อีเมลหรือรหัสผ่านไม่ถูกต้อง' });
                }
            } catch (compareError) {
                console.error("Bcrypt compare error: ", compareError);
                res.status(500).json({ success: false, message: 'Error during authentication' });
            }
        } else {
            console.log("Login Error: User email not found");
            res.status(401).json({ success: false, message: 'อีเมลหรือรหัสผ่านไม่ถูกต้อง' });
        }
    });
});

/* POST /register */
app.post('/register', async (req, res) => {
    const { email, password, full_name, role } = req.body;
    if (!email || !password || !full_name || !role) {
        return res.status(400).json({ message: 'Please provide all fields.' });
    }
    const allowedRoles = ['student', 'lecture', 'staff'];
    if (!allowedRoles.includes(role)) {
        return res.status(400).json({ message: 'Invalid role specified.' });
    }
    try {
        const hashedPassword = await bcrypt.hash(password, saltRounds);
        const sql = `INSERT INTO users (email, password_hash, full_name, role) VALUES (?, ?, ?, ?);`;
        const values = [email, hashedPassword, full_name, role];
        con.query(sql, values, (err, result) => {
            if (err) {
                console.error("DB Error (Register): ", err);
                if (err.code === 'ER_DUP_ENTRY') {
                    return res.status(409).json({ message: 'This email is already registered.' });
                }
                return res.status(500).json({ message: 'Database server error.' });
            }
            res.status(201).json({ success: true, message: 'User registered successfully!', userId: result.insertId });
        });
    } catch (hashError) {
        console.error("Bcrypt hash error: ", hashError);
        res.status(500).json({ message: 'Error processing registration.' });
    }
});

// =================================================================
// Role: Student
// =================================================================

/* POST /borrow-request (Student) */
app.post('/borrow-request', (req, res) => {
    const { product_id, student_user_id, start_date, end_date } = req.body;
    if (!product_id || !student_user_id || !start_date || !end_date) {
        return res.status(400).json({ message: 'ข้อมูลไม่ครบถ้วน' });
    }
    const checkSql = "SELECT request_id FROM borrow_requests WHERE student_user_id = ? AND status IN ('Pending', 'Approved')";
    con.query(checkSql, [student_user_id], (err, results) => {
        if (err) {
            console.error("DB Check Error: ", err);
            return res.status(500).json({ message: 'Database server error (Check)' });
        }
        if (results.length > 0) {
            return res.status(409).json({ message: 'You can only borrow once per day.' });
        }
        const insertSql = "INSERT INTO borrow_requests (product_id, student_user_id, borrow_start_date, borrow_end_date, status) VALUES (?, ?, ?, ?, 'Pending')";
        const values = [product_id, student_user_id, start_date, end_date];
        con.query(insertSql, values, (err, insertResult) => {
            if (err) {
                console.error("DB Insert Error: ", err);
                return res.status(500).json({ message: 'Database server error (Insert)' });
            }
            res.status(201).json({ success: true, message: 'Request submitted successfully!', request_id: insertResult.insertId });
        });
    });
});

/* DELETE /borrow-request/:requestId (Student) */
app.delete('/borrow-request/:requestId', (req, res) => {
    const requestId = req.params.requestId;
    if (!requestId) {
        return res.status(400).json({ message: 'Request ID is required.' });
    }
    const sql = "DELETE FROM borrow_requests WHERE request_id = ? AND status = 'Pending'";
    con.query(sql, [requestId], (err, result) => {
        if (err) {
            console.error("DB Error (Cancel Request): ", err);
            return res.status(500).json({ message: 'Database server error' });
        }
        if (result.affectedRows > 0) {
            res.json({ success: true, message: 'Request cancelled successfully.' });
        } else {
            res.status(404).json({ message: 'Pending request not found or cannot be cancelled.' });
        }
    });
});

/* GET /my-request-status/:studentId (Student) */
app.get('/my-request-status/:studentId', (req, res) => {
    const studentId = req.params.studentId;
    if (!studentId) {
        return res.status(400).json({ message: 'Student ID is required.' });
    }
    const sql = `
        SELECT br.request_id, br.status, br.borrow_start_date, br.borrow_end_date, br.disapprove_reason,
               p.product_name, p.product_detail, p.image_url
        FROM borrow_requests AS br
        JOIN products AS p ON br.product_id = p.product_id
        WHERE br.student_user_id = ? 
        ORDER BY br.request_id DESC
        LIMIT 1;
    `;
    con.query(sql, [studentId], (err, results) => {
        if (err) {
            console.error("DB Error (My Request Status): ", err);
            return res.status(500).json({ message: 'Database server error' });
        }
        if (results.length > 0) {
            res.json(results[0]);
        } else {
            res.json(null);
        }
    });
});

/* GET /history/student/:id (Student) */
app.get('/history/student/:id', (req, res) => {
    const studentId = req.params.id;
    const sql = `
        SELECT p.product_name, p.image_url, p.product_id,
               br.borrow_start_date, br.actual_return_date, br.status,
               lecturer.full_name AS approve_by_name,
               staff.full_name AS received_by_name
        FROM borrow_requests AS br
        JOIN products AS p ON br.product_id = p.product_id
        LEFT JOIN users AS lecturer ON br.lecture_user_id = lecturer.user_id
        LEFT JOIN users AS staff ON br.staff_received_user_id = staff.user_id
        WHERE br.student_user_id = ?
        ORDER BY br.request_date DESC;
    `;
    con.query(sql, [studentId], (err, results) => {
        if (err) {
            console.error("DB Error (History Student): ", err);
            return res.status(500).json({ message: 'Database server error' });
        }
        res.json(results);
    });
});

/* GET /products (ใช้ร่วมกัน Student/Staff) */
app.get('/products', (_req, res) => {
    const sql = "SELECT * FROM products";
    con.query(sql, (err, results) => {
        if (err) {
            console.error("Database error: ", err);
            return res.status(500).send("Database server error");
        }
        res.json(results);
    });
});

// =================================================================
// Role: Lecture
// =================================================================

/* POST /approve-request (Lecture) */
app.post('/approve-request', (req, res) => {
    const { request_id, lecture_user_id, product_id } = req.body;
    if (!request_id || !lecture_user_id || !product_id) {
        return res.status(400).json({ message: 'ข้อมูลไม่ครบถ้วน' });
    }
    const sqlRequest = "UPDATE borrow_requests SET status = 'Approved', lecture_user_id = ?, decision_date = NOW() WHERE request_id = ?";
    con.query(sqlRequest, [lecture_user_id, request_id], (err, result) => {
        if (err || result.affectedRows === 0) {
            console.error("DB Error (Approve Request): ", err);
            return res.status(err ? 500 : 404).json({ message: err ? 'DB error' : 'Request not found' });
        }
        const sqlProduct = "UPDATE products SET status = 'Borrowed' WHERE product_id = ?";
        con.query(sqlProduct, [product_id], (err, prodResult) => {
            if (err) {
                console.error("DB Error (Update Product Status): ", err);
                return res.status(500).json({ message: 'Database server error (Product)' });
            }
            res.json({ success: true, message: 'Request approved successfully!' });
        });
    });
});

/* POST /disapprove-request (Lecture) */
app.post('/disapprove-request', (req, res) => {
    const { request_id, lecture_user_id, reason } = req.body;
    if (!request_id || !lecture_user_id) {
        return res.status(400).json({ message: 'ข้อมูลไม่ครบถ้วน' });
    }
    const sql = "UPDATE borrow_requests SET status = 'Disapproved', lecture_user_id = ?, decision_date = NOW(), disapprove_reason = ? WHERE request_id = ?";
    con.query(sql, [lecture_user_id, reason, request_id], (err, result) => {
        if (err) {
            console.error("DB Error (Disapprove): ", err);
            return res.status(500).json({ message: 'Database server error' });
        }
        if (result.affectedRows === 0) {
            return res.status(404).json({ message: 'Request not found' });
        }
        res.json({ success: true, message: 'Request disapproved successfully!' });
    });
});

/* GET /pending-requests (Lecture) */
app.get('/pending-requests', (_req, res) => {
    const sql = `
        SELECT br.request_id, br.borrow_start_date, br.borrow_end_date,
               p.product_id, p.product_name, p.image_url,
               u.full_name AS requested_by_name
        FROM borrow_requests AS br
        JOIN products AS p ON br.product_id = p.product_id
        JOIN users AS u ON br.student_user_id = u.user_id
        WHERE br.status = 'Pending'
        ORDER BY br.request_date ASC;
    `;
    con.query(sql, (err, results) => {
        if (err) {
            console.error("Database error: ", err);
            return res.status(500).json({ message: 'Database server error' });
        }
        res.json(results);
    });
});

/* GET /history/lecture/:id (Lecture) */
app.get('/history/lecture/:id', (req, res) => {
    const lectureId = req.params.id;
    const sql = `
        SELECT p.product_name, p.image_url, p.product_id,
               br.borrow_start_date, br.borrow_end_date, br.decision_date, br.status,
               student.full_name AS requested_by_name
        FROM borrow_requests AS br
        JOIN products AS p ON br.product_id = p.product_id
        JOIN users AS student ON br.student_user_id = student.user_id
        WHERE br.lecture_user_id = ? AND br.status IN ('Approved', 'Disapproved')
        ORDER BY br.decision_date DESC;
    `;
    con.query(sql, [lectureId], (err, results) => {
        if (err) {
            console.error("DB Error (History Lecture): ", err);
            return res.status(500).json({ message: 'Database server error' });
        }
        res.json(results);
    });
});

/* GET /dashboard-summary (ใช้ร่วมกัน Lecture/Staff) */
app.get('/dashboard-summary', (_req, res) => {
    const productSql = `
        SELECT COUNT(*) AS totalAssets,
               SUM(CASE WHEN status = 'Borrowed' THEN 1 ELSE 0 END) AS borrowed,
               SUM(CASE WHEN status = 'Disabled' THEN 1 ELSE 0 END) AS disabled,
               SUM(CASE WHEN status = 'Available' THEN 1 ELSE 0 END) AS available
        FROM products;
    `;
    const pendingSql = `
        SELECT COUNT(*) AS pending
        FROM borrow_requests 
        WHERE status = 'Pending';
    `;
    Promise.all([
        new Promise((resolve, reject) => {
            con.query(productSql, (err, results) => err ? reject(err) : resolve(results[0]));
        }),
        new Promise((resolve, reject) => {
            con.query(pendingSql, (err, results) => err ? reject(err) : resolve(results[0]));
        })
    ]).then(([productCounts, pendingCount]) => {
        const summary = { ...productCounts, ...pendingCount };
        res.json(summary);
    }).catch(err => {
        console.error("DB Error (Dashboard): ", err);
        res.status(500).json({ message: 'Database server error' });
    });
});

// =================================================================
// Role: Staff
// =================================================================

/* POST /upload (Upload Image - Staff) */
app.post('/upload', upload.single('assetImage'), (req, res) => {
    if (!req.file) {
        return res.status(400).send('No file uploaded.');
    }
    const fileUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
    res.json({ imageUrl: fileUrl });
});

/* POST /products (Add Asset - Staff) */
// [แก้ไข] 1. สร้าง ID อัตโนมัติ (ลบ product_id ออกจาก req.body)
app.post('/products', (req, res) => {
    const { product_name, product_detail, image_url, status } = req.body;

    if (!product_name || !status) {
        return res.status(400).json({ message: 'Product Name and Status are required.' });
    }

    // 2. สร้าง Prefix
    const prefix = product_name.substring(0, 2).toUpperCase();
    const searchPattern = `${prefix}-%`;

    // 3. ค้นหา ID ล่าสุด
    const findSql = "SELECT product_id FROM products WHERE product_id LIKE ? ORDER BY product_id DESC LIMIT 1";

    con.query(findSql, [searchPattern], (err, results) => {
        if (err) {
            console.error("DB Error (Find Last ID): ", err);
            return res.status(500).json({ message: 'Database error finding last ID' });
        }

        let newNumber = 1;
        if (results.length > 0) {
            const lastId = results[0].product_id;
            const lastNumberStr = lastId.split('-')[1];
            const lastNumber = parseInt(lastNumberStr, 10);
            newNumber = lastNumber + 1;
        }

        // 4. สร้าง ID ใหม่
        const newPaddedNumber = String(newNumber).padStart(4, '0');
        const newProductId = `${prefix}-${newPaddedNumber}`;

        // 5. บันทึกข้อมูล
        const insertSql = `
            INSERT INTO products (product_id, product_name, product_detail, image_url, status)
            VALUES (?, ?, ?, ?, ?);
        `;
        const values = [newProductId, product_name, product_detail || '', image_url, status];

        con.query(insertSql, values, (err, result) => {
            if (err) {
                console.error("DB Error (Insert Product): ", err);
                // (ไม่น่าจะเกิด ER_DUP_ENTRY แล้ว แต่เก็บไว้กันเหนียว)
                if (err.code === 'ER_DUP_ENTRY') {
                    return res.status(409).json({ message: 'Error: Product ID already exists.' });
                }
                return res.status(500).json({ message: 'Database server error' });
            }
            res.status(201).json({
                success: true,
                message: 'Asset added successfully!',
                newProductId: newProductId
            });
        });
    });
});

/* PUT /products/:id (Edit Asset - Staff) */
app.put('/products/:id', (req, res) => {
    const productId = req.params.id;
    const { product_name, product_detail, status } = req.body;
    if (!product_name || !status) {
        return res.status(400).json({ message: 'Product Name and Status are required.' });
    }
    const sql = `UPDATE products SET product_name = ?, product_detail = ?, status = ? WHERE product_id = ?;`;
    const values = [product_name, product_detail || '', status, productId];
    con.query(sql, values, (err, result) => {
        if (err) {
            console.error("DB Error (Update Product): ", err);
            return res.status(500).json({ message: 'Database server error' });
        }
        if (result.affectedRows === 0) {
            return res.status(404).json({ message: 'Product not found' });
        }
        res.json({ success: true, message: 'Asset updated successfully!' });
    });
});

/* PUT /products/:id/status (Disable Asset - Staff) */
app.put('/products/:id/status', (req, res) => {
    const productId = req.params.id;
    const { status } = req.body;
    if (!status) {
        return res.status(400).json({ message: 'Status is required.' });
    }
    const allowedStatuses = ['Available', 'Borrowed', 'Disabled', 'Pending'];
    if (!allowedStatuses.includes(status)) {
        return res.status(400).json({ message: 'Invalid status value.' });
    }
    const sql = `UPDATE products SET status = ? WHERE product_id = ?;`;
    con.query(sql, [status, productId], (err, result) => {
        if (err) {
            console.error("DB Error (Update Status): ", err);
            return res.status(500).json({ message: 'Database server error' });
        }
        if (result.affectedRows === 0) {
            return res.status(404).json({ message: 'Product not found' });
        }
        res.json({ success: true, message: `Asset status updated to ${status}!` });
    });
});

/* GET /borrowed-items (Staff) */
app.get('/borrowed-items', (_req, res) => {
    const sql = `
        SELECT br.request_id, p.product_id, p.product_name, p.image_url,
               u.full_name AS borrowed_by_name,
               br.borrow_end_date AS due_date
        FROM borrow_requests AS br
        JOIN products AS p ON br.product_id = p.product_id
        JOIN users AS u ON br.student_user_id = u.user_id
        WHERE br.status = 'Approved'
        ORDER BY br.borrow_end_date ASC;
    `;
    con.query(sql, (err, results) => {
        if (err) {
            console.error("DB Error (Borrowed Items): ", err);
            return res.status(500).json({ message: 'Database server error' });
        }
        res.json(results);
    });
});

/* POST /confirm-return (Staff) */
app.post('/confirm-return', (req, res) => {
    const { request_id, staff_user_id, product_id } = req.body;
    if (!request_id || !staff_user_id || !product_id) {
        return res.status(400).json({ message: 'ข้อมูลไม่ครบถ้วน' });
    }
    const sqlRequest = "UPDATE borrow_requests SET status = 'Returned', staff_received_user_id = ?, actual_return_date = NOW() WHERE request_id = ?";
    con.query(sqlRequest, [staff_user_id, request_id], (err, result) => {
        if (err || result.affectedRows === 0) {
            console.error("DB Error (Confirm Return): ", err);
            return res.status(err ? 500 : 404).json({ message: err ? 'DB error' : 'Request not found' });
        }
        const sqlProduct = "UPDATE products SET status = 'Available' WHERE product_id = ?";
        con.query(sqlProduct, [product_id], (err, prodResult) => {
            if (err) {
                console.error("DB Error (Update Product Status): ", err);
                return res.status(500).json({ message: 'Database server error (Product)' });
            }
            res.json({ success: true, message: 'Return confirmed successfully!' });
        });
    });
});

/* GET /history/staff (Staff) */
app.get('/history/staff', (_req, res) => {
    const sql = `
        SELECT p.product_name, p.image_url, p.product_id,
               br.borrow_start_date, br.actual_return_date, br.status,
               student.full_name AS borrowed_by_name,
               lecturer.full_name AS approved_by_name,
               staff.full_name AS received_by_name
        FROM borrow_requests AS br
        JOIN products AS p ON br.product_id = p.product_id
        JOIN users AS student ON br.student_user_id = student.user_id
        LEFT JOIN users AS lecturer ON br.lecture_user_id = lecturer.user_id
        LEFT JOIN users AS staff ON br.staff_received_user_id = staff.user_id
        WHERE br.status = 'Returned'
        ORDER BY br.actual_return_date DESC;
    `;
    con.query(sql, (err, results) => {
        if (err) {
            console.error("DB Error (History Staff): ", err);
            return res.status(500).json({ message: 'Database server error' });
        }
        res.json(results);
    });
});

// ---------- Server starts here ---------
const PORT = 4700;
app.listen(PORT, () => {
    // สร้าง folder 'uploads' ถ้ายังไม่มี
    const uploadsDir = './uploads';
    if (!fs.existsSync(uploadsDir)) {
        fs.mkdirSync(uploadsDir);
        console.log("Created 'uploads' directory.");
    }
    console.log(`Server is running at http://localhost:${PORT}`);
});