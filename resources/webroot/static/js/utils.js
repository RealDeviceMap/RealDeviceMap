function strip(value) {
    return value.replace(/,/g, "");
}

function addDataset(chart, data) {
    chart.data.datasets.push(data);
    chart.update();
}

function removeDataset(chart) {
    //chart.data.datasets.shift();
    chart.data.datasets = [];
    //chart.data.labels.pop();
    //chart.data.datasets.forEach((dataset) => {
    //  dataset.data.pop();
    //});
    chart.update();
}

function numberWithCommas(x) {
    return x.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

function updateCounter(name, value) {
    $({ counter: 0 }).animate({ counter: value }, {
        duration: 1500,
        easing: 'swing', // can be anything
        step: function() { // called on every step
            // Update the element's text with rounded-up value:
            $(name).text(numberWithCommas(Math.round(this.counter)));
        }
    });
}

function colorize(opaque, hover, ctx) {
    var v = ctx.dataset.data[ctx.dataIndex];
    var c = v < -50 ? '#D60000'
        : v < 0 ? '#F46300'
            : v < 50 ? '#0358B6'
                : '#7f887e';
    var opacity = hover ? 1 - Math.abs(v / 150) - 0.2 : 1 - Math.abs(v / 150);
    return opaque ? c : transparentize(c, opacity);
}

function hoverColorize(ctx) {
    return colorize(false, true, ctx);
}

function transparentize(color, opacity) {
    var alpha = opacity === undefined ? 0.5 : 1 - opacity;
    return Color(color).alpha(alpha).rgbString();
}

function unixToDate(unixTimestamp) {
    var date = new Date(unixTimestamp * 1000);
    var year = date.getFullYear();
    var month = date.getMonth() + 1;
    var day = date.getDate();
    var formatted = year + "-" + month + "-" + day;
    return formatted;
}
