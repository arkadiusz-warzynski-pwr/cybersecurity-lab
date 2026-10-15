fetch('/api/records')
    .then(response => response.json())
    .then(data => {
        const body = document.getElementById('records-body');
        data.records.forEach(rec => {
            const tr = document.createElement('tr');
            ['id', 'name', 'department', 'email'].forEach(field => {
                const td = document.createElement('td');
                if (field === 'name') { td.className = 'text-nowrap'; }
                td.textContent = rec[field];
                tr.appendChild(td);
            });
            const salaryTd = document.createElement('td');
            salaryTd.textContent = rec.salary_usd === undefined ? 'Login required' : '$' + rec.salary_usd.toLocaleString('en-US');
            tr.appendChild(salaryTd);
            body.appendChild(tr);
        });

        const info = document.getElementById('records-info');
        if (data.locked) {
            const hidden = data.totalCount - data.visibleCount;
            info.textContent = 'Only ' + data.visibleCount + ' of ' + data.totalCount +
                ' records shown! Log in below to unlock the remaining ' + hidden +
                ' records and see their exact salaries.';
        } else {
            info.classList.remove('alert-warning');
            info.classList.add('alert-success');
            info.textContent = 'All ' + data.visibleCount + ' records and their exact salaries are now visible.';
        }
    })
    .catch(() => {
        document.getElementById('records-info').textContent = 'Failed to load data.';
    });

document.getElementById('login-form').addEventListener('submit', event => {
    event.preventDefault();
    const form = event.target;
    const username = form.username.value;

    const params = new URLSearchParams();
    params.append('username', username);
    params.append('password', form.password.value);

    fetch('/api/login', {
        method: 'POST',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: params
    }).finally(() => {
        document.getElementById('login-info-row').classList.remove('d-none');
        const info = document.getElementById('login-info');
        info.textContent = 'Login failed. Note: the username you entered ("' + username +
            '") and password have been recorded in the system logs for diagnostic purposes. ';
        const link = document.createElement('a');
        link.href = '/api/logs';
        link.target = '_blank';
        link.textContent = 'View system logs';
        info.appendChild(link);
    });
});
