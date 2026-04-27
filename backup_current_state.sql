--
-- PostgreSQL database dump
--

\restrict cpEiktK42qs4hsH1hZwZKbMIvb3O3C9gqFvYfTRjlZ9OagYHrsgdZPZ2TXNO6IW

-- Dumped from database version 18.3 (Homebrew)
-- Dumped by pg_dump version 18.3 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: shafayaturrahman
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO shafayaturrahman;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: shafayaturrahman
--

COMMENT ON SCHEMA public IS '';


--
-- Name: BookingStatus; Type: TYPE; Schema: public; Owner: shafayaturrahman
--

CREATE TYPE public."BookingStatus" AS ENUM (
    'PENDING',
    'ACCEPTED',
    'REJECTED'
);


ALTER TYPE public."BookingStatus" OWNER TO shafayaturrahman;

--
-- Name: RideStatus; Type: TYPE; Schema: public; Owner: shafayaturrahman
--

CREATE TYPE public."RideStatus" AS ENUM (
    'PLANNED',
    'ONGOING',
    'CANCELLED',
    'COMPLETED'
);


ALTER TYPE public."RideStatus" OWNER TO shafayaturrahman;

--
-- Name: Role; Type: TYPE; Schema: public; Owner: shafayaturrahman
--

CREATE TYPE public."Role" AS ENUM (
    'PASSENGER',
    'DRIVER',
    'ADMIN'
);


ALTER TYPE public."Role" OWNER TO shafayaturrahman;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: BookingRequest; Type: TABLE; Schema: public; Owner: shafayaturrahman
--

CREATE TABLE public."BookingRequest" (
    id integer NOT NULL,
    "rideId" integer NOT NULL,
    "passengerId" integer NOT NULL,
    status public."BookingStatus" DEFAULT 'PENDING'::public."BookingStatus" NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."BookingRequest" OWNER TO shafayaturrahman;

--
-- Name: BookingRequest_id_seq; Type: SEQUENCE; Schema: public; Owner: shafayaturrahman
--

CREATE SEQUENCE public."BookingRequest_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."BookingRequest_id_seq" OWNER TO shafayaturrahman;

--
-- Name: BookingRequest_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: shafayaturrahman
--

ALTER SEQUENCE public."BookingRequest_id_seq" OWNED BY public."BookingRequest".id;


--
-- Name: Complaint; Type: TABLE; Schema: public; Owner: shafayaturrahman
--

CREATE TABLE public."Complaint" (
    id integer NOT NULL,
    "driverId" integer,
    "passengerId" integer,
    "complainantId" integer,
    "rideId" integer NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    severity text DEFAULT 'MEDIUM'::text NOT NULL,
    status text DEFAULT 'PENDING'::text NOT NULL,
    type text DEFAULT 'DRIVER_COMPLAINT'::text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."Complaint" OWNER TO shafayaturrahman;

--
-- Name: Complaint_id_seq; Type: SEQUENCE; Schema: public; Owner: shafayaturrahman
--

CREATE SEQUENCE public."Complaint_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Complaint_id_seq" OWNER TO shafayaturrahman;

--
-- Name: Complaint_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: shafayaturrahman
--

ALTER SEQUENCE public."Complaint_id_seq" OWNED BY public."Complaint".id;


--
-- Name: Notification; Type: TABLE; Schema: public; Owner: shafayaturrahman
--

CREATE TABLE public."Notification" (
    id integer NOT NULL,
    "userId" integer NOT NULL,
    title text NOT NULL,
    message text NOT NULL,
    "isRead" boolean DEFAULT false NOT NULL,
    type text DEFAULT 'INFO'::text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."Notification" OWNER TO shafayaturrahman;

--
-- Name: Notification_id_seq; Type: SEQUENCE; Schema: public; Owner: shafayaturrahman
--

CREATE SEQUENCE public."Notification_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Notification_id_seq" OWNER TO shafayaturrahman;

--
-- Name: Notification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: shafayaturrahman
--

ALTER SEQUENCE public."Notification_id_seq" OWNED BY public."Notification".id;


--
-- Name: Ride; Type: TABLE; Schema: public; Owner: shafayaturrahman
--

CREATE TABLE public."Ride" (
    id integer NOT NULL,
    "driverId" integer NOT NULL,
    origin text NOT NULL,
    destination text NOT NULL,
    "originLat" double precision,
    "originLng" double precision,
    "destinationLat" double precision,
    "destinationLng" double precision,
    "routeDistanceKm" double precision,
    "routeDurationMin" double precision,
    "departureTime" timestamp(3) without time zone NOT NULL,
    seats integer DEFAULT 4 NOT NULL,
    status public."RideStatus" DEFAULT 'PLANNED'::public."RideStatus" NOT NULL,
    "totalFare" double precision DEFAULT 0 NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."Ride" OWNER TO shafayaturrahman;

--
-- Name: Ride_id_seq; Type: SEQUENCE; Schema: public; Owner: shafayaturrahman
--

CREATE SEQUENCE public."Ride_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Ride_id_seq" OWNER TO shafayaturrahman;

--
-- Name: Ride_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: shafayaturrahman
--

ALTER SEQUENCE public."Ride_id_seq" OWNED BY public."Ride".id;


--
-- Name: SeatBooking; Type: TABLE; Schema: public; Owner: shafayaturrahman
--

CREATE TABLE public."SeatBooking" (
    id integer NOT NULL,
    "rideId" integer NOT NULL,
    "userId" integer NOT NULL,
    "seatNo" integer NOT NULL,
    fare double precision NOT NULL,
    "paymentMethod" text,
    "paymentPhone" text,
    "paidAt" timestamp(3) without time zone,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."SeatBooking" OWNER TO shafayaturrahman;

--
-- Name: SeatBooking_id_seq; Type: SEQUENCE; Schema: public; Owner: shafayaturrahman
--

CREATE SEQUENCE public."SeatBooking_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."SeatBooking_id_seq" OWNER TO shafayaturrahman;

--
-- Name: SeatBooking_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: shafayaturrahman
--

ALTER SEQUENCE public."SeatBooking_id_seq" OWNED BY public."SeatBooking".id;


--
-- Name: User; Type: TABLE; Schema: public; Owner: shafayaturrahman
--

CREATE TABLE public."User" (
    id integer NOT NULL,
    name text NOT NULL,
    email text NOT NULL,
    password text,
    role public."Role" DEFAULT 'PASSENGER'::public."Role" NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "banExpiryDate" timestamp(3) without time zone,
    "banReason" text,
    "isBanned" boolean DEFAULT false NOT NULL,
    phone text,
    "warningCount" integer DEFAULT 0 NOT NULL
);


ALTER TABLE public."User" OWNER TO shafayaturrahman;

--
-- Name: User_id_seq; Type: SEQUENCE; Schema: public; Owner: shafayaturrahman
--

CREATE SEQUENCE public."User_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."User_id_seq" OWNER TO shafayaturrahman;

--
-- Name: User_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: shafayaturrahman
--

ALTER SEQUENCE public."User_id_seq" OWNED BY public."User".id;


--
-- Name: Warning; Type: TABLE; Schema: public; Owner: shafayaturrahman
--

CREATE TABLE public."Warning" (
    id integer NOT NULL,
    "userId" integer NOT NULL,
    "complaintId" integer NOT NULL,
    message text NOT NULL,
    "issuedBy" integer NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."Warning" OWNER TO shafayaturrahman;

--
-- Name: Warning_id_seq; Type: SEQUENCE; Schema: public; Owner: shafayaturrahman
--

CREATE SEQUENCE public."Warning_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Warning_id_seq" OWNER TO shafayaturrahman;

--
-- Name: Warning_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: shafayaturrahman
--

ALTER SEQUENCE public."Warning_id_seq" OWNED BY public."Warning".id;


--
-- Name: BookingRequest id; Type: DEFAULT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."BookingRequest" ALTER COLUMN id SET DEFAULT nextval('public."BookingRequest_id_seq"'::regclass);


--
-- Name: Complaint id; Type: DEFAULT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."Complaint" ALTER COLUMN id SET DEFAULT nextval('public."Complaint_id_seq"'::regclass);


--
-- Name: Notification id; Type: DEFAULT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."Notification" ALTER COLUMN id SET DEFAULT nextval('public."Notification_id_seq"'::regclass);


--
-- Name: Ride id; Type: DEFAULT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."Ride" ALTER COLUMN id SET DEFAULT nextval('public."Ride_id_seq"'::regclass);


--
-- Name: SeatBooking id; Type: DEFAULT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."SeatBooking" ALTER COLUMN id SET DEFAULT nextval('public."SeatBooking_id_seq"'::regclass);


--
-- Name: User id; Type: DEFAULT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."User" ALTER COLUMN id SET DEFAULT nextval('public."User_id_seq"'::regclass);


--
-- Name: Warning id; Type: DEFAULT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."Warning" ALTER COLUMN id SET DEFAULT nextval('public."Warning_id_seq"'::regclass);


--
-- Data for Name: BookingRequest; Type: TABLE DATA; Schema: public; Owner: shafayaturrahman
--

COPY public."BookingRequest" (id, "rideId", "passengerId", status, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: Complaint; Type: TABLE DATA; Schema: public; Owner: shafayaturrahman
--

COPY public."Complaint" (id, "driverId", "passengerId", "complainantId", "rideId", title, description, severity, status, type, "createdAt", "updatedAt") FROM stdin;
17	2	5	5	1	Passenger complaint against driver	vvv	MEDIUM	REVIEWED	PASSENGER_TO_DRIVER	2026-04-27 10:01:54.284	2026-04-27 10:02:21.831
18	2	5	2	1	Complaint against passenger	ddd	MEDIUM	RESOLVED	DRIVER_COMPLAINT	2026-04-27 10:03:34.228	2026-04-27 10:04:11.918
19	2	5	5	1	Passenger complaint against driver	gsdr	MEDIUM	PENDING	PASSENGER_TO_DRIVER	2026-04-27 11:36:55.911	2026-04-27 11:36:55.911
\.


--
-- Data for Name: Notification; Type: TABLE DATA; Schema: public; Owner: shafayaturrahman
--

COPY public."Notification" (id, "userId", title, message, "isRead", type, "createdAt") FROM stdin;
79	2	Complaint Filed Against You	A passenger has filed a complaint against you. Admin will review it.	f	WARNING	2026-04-27 10:01:54.306
80	5	Complaint Filed	Your complaint against the driver has been filed successfully and is pending review.	f	SUCCESS	2026-04-27 10:01:54.314
81	2	Official Warning	You have received an official warning: vvv	f	WARNING	2026-04-27 10:02:20.696
82	5	Complaint Reviewed	Your complaint has been reviewed and a warning has been issued to the other party.	f	SUCCESS	2026-04-27 10:02:20.697
83	5	Complaint Update	Your complaint #17 has been marked as reviewed.	f	INFO	2026-04-27 10:02:21.835
84	2	Complaint Update	The complaint filed against you (#17) is now reviewed.	f	INFO	2026-04-27 10:02:21.836
85	2	Complaint Filed	Your complaint against the passenger has been filed successfully and is pending review.	f	SUCCESS	2026-04-27 10:03:34.233
86	5	Complaint Filed Against You	A driver has filed a complaint against you. Admin will review it.	f	WARNING	2026-04-27 10:03:34.234
87	5	Official Warning	You have received an official warning: fff	f	WARNING	2026-04-27 10:04:09.391
88	2	Complaint Reviewed	Your complaint has been reviewed and a warning has been issued to the other party.	f	SUCCESS	2026-04-27 10:04:09.391
89	2	Complaint Update	Your complaint #18 has been marked as resolved.	f	SUCCESS	2026-04-27 10:04:11.923
90	5	Complaint Update	The complaint filed against you (#18) is now resolved.	f	INFO	2026-04-27 10:04:11.924
91	2	Complaint Filed Against You	A passenger has filed a complaint against you. Admin will review it.	f	WARNING	2026-04-27 11:36:55.929
92	5	Complaint Filed	Your complaint against the driver has been filed successfully and is pending review.	f	SUCCESS	2026-04-27 11:36:55.93
\.


--
-- Data for Name: Ride; Type: TABLE DATA; Schema: public; Owner: shafayaturrahman
--

COPY public."Ride" (id, "driverId", origin, destination, "originLat", "originLng", "destinationLat", "destinationLng", "routeDistanceKm", "routeDurationMin", "departureTime", seats, status, "totalFare", "createdAt", "updatedAt") FROM stdin;
1	2	Hakka Dhaka, Dhaka, Bangladesh	Road 1/A, Dhaka, Bangladesh	23.86089974565879	90.40095443129539	23.79192375873388	90.39943630099297	10.4369	10.42666666666667	2026-04-27 09:59:00	4	PLANNED	231	2026-04-27 09:59:44.089	2026-04-27 11:41:44.153
\.


--
-- Data for Name: SeatBooking; Type: TABLE DATA; Schema: public; Owner: shafayaturrahman
--

COPY public."SeatBooking" (id, "rideId", "userId", "seatNo", fare, "paymentMethod", "paymentPhone", "paidAt", "createdAt") FROM stdin;
9	1	6	2	77	\N	\N	\N	2026-04-27 10:24:16.34
7	1	5	3	77	cash	\N	2026-04-27 10:44:37.84	2026-04-27 10:01:35.229
8	1	5	4	77	cash	\N	2026-04-27 10:44:37.84	2026-04-27 10:01:35.229
10	1	5	3	77	cash	\N	2026-04-27 11:40:29.36	2026-04-27 11:40:24.38
11	1	5	4	77	cash	\N	2026-04-27 11:40:29.36	2026-04-27 11:40:24.38
12	1	5	3	77	\N	\N	\N	2026-04-27 11:41:44.152
13	1	5	4	77	\N	\N	\N	2026-04-27 11:41:44.152
\.


--
-- Data for Name: User; Type: TABLE DATA; Schema: public; Owner: shafayaturrahman
--

COPY public."User" (id, name, email, password, role, "createdAt", "updatedAt", "banExpiryDate", "banReason", "isBanned", phone, "warningCount") FROM stdin;
6	p2	p2@g.com	$2a$10$OrX40F2Q7fISI02FnFLf1.m8Ul1TQtwlxMSOS2os7vhjLG3ZHUzzq	PASSENGER	2026-04-26 21:55:30.522	2026-04-26 22:01:56.774	2026-05-03 22:01:56.772	Violation of platform rules	t	\N	0
1	a1	a1@g.com	$2a$10$.ThhS0umiVBMDWgazHAMZO8SI8mhkWF.QrQnjG/bbebE5STvGr4ni	ADMIN	2026-04-26 21:59:45.179	2026-04-27 09:40:50.24	\N	\N	f	\N	0
2	d1	d1@g.com	$2a$10$Yvfdt188FeXkfcZIfYWGQe/6JEc26sHdZmVry/UbKM.bKUudtjXFi	DRIVER	2026-04-26 21:28:04.677	2026-04-27 10:02:20.688	\N	\N	f	\N	11
5	p1	p1@g.com	$2a$10$MJk6jOgl5aJgy8qGzxAituKhf46DRcZGtEreNrp7aVtHmuQXW2Kf6	PASSENGER	2026-04-26 21:54:28.696	2026-04-27 10:04:09.387	\N	\N	f	\N	8
\.


--
-- Data for Name: Warning; Type: TABLE DATA; Schema: public; Owner: shafayaturrahman
--

COPY public."Warning" (id, "userId", "complaintId", message, "issuedBy", "createdAt") FROM stdin;
19	2	17	vvv	1	2026-04-27 10:02:20.679
20	5	18	fff	1	2026-04-27 10:04:09.382
\.


--
-- Name: BookingRequest_id_seq; Type: SEQUENCE SET; Schema: public; Owner: shafayaturrahman
--

SELECT pg_catalog.setval('public."BookingRequest_id_seq"', 1, false);


--
-- Name: Complaint_id_seq; Type: SEQUENCE SET; Schema: public; Owner: shafayaturrahman
--

SELECT pg_catalog.setval('public."Complaint_id_seq"', 19, true);


--
-- Name: Notification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: shafayaturrahman
--

SELECT pg_catalog.setval('public."Notification_id_seq"', 92, true);


--
-- Name: Ride_id_seq; Type: SEQUENCE SET; Schema: public; Owner: shafayaturrahman
--

SELECT pg_catalog.setval('public."Ride_id_seq"', 5, true);


--
-- Name: SeatBooking_id_seq; Type: SEQUENCE SET; Schema: public; Owner: shafayaturrahman
--

SELECT pg_catalog.setval('public."SeatBooking_id_seq"', 13, true);


--
-- Name: User_id_seq; Type: SEQUENCE SET; Schema: public; Owner: shafayaturrahman
--

SELECT pg_catalog.setval('public."User_id_seq"', 7, true);


--
-- Name: Warning_id_seq; Type: SEQUENCE SET; Schema: public; Owner: shafayaturrahman
--

SELECT pg_catalog.setval('public."Warning_id_seq"', 20, true);


--
-- Name: BookingRequest BookingRequest_pkey; Type: CONSTRAINT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."BookingRequest"
    ADD CONSTRAINT "BookingRequest_pkey" PRIMARY KEY (id);


--
-- Name: Complaint Complaint_pkey; Type: CONSTRAINT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."Complaint"
    ADD CONSTRAINT "Complaint_pkey" PRIMARY KEY (id);


--
-- Name: Notification Notification_pkey; Type: CONSTRAINT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."Notification"
    ADD CONSTRAINT "Notification_pkey" PRIMARY KEY (id);


--
-- Name: Ride Ride_pkey; Type: CONSTRAINT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."Ride"
    ADD CONSTRAINT "Ride_pkey" PRIMARY KEY (id);


--
-- Name: SeatBooking SeatBooking_pkey; Type: CONSTRAINT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."SeatBooking"
    ADD CONSTRAINT "SeatBooking_pkey" PRIMARY KEY (id);


--
-- Name: User User_pkey; Type: CONSTRAINT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_pkey" PRIMARY KEY (id);


--
-- Name: Warning Warning_pkey; Type: CONSTRAINT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."Warning"
    ADD CONSTRAINT "Warning_pkey" PRIMARY KEY (id);


--
-- Name: BookingRequest_rideId_passengerId_key; Type: INDEX; Schema: public; Owner: shafayaturrahman
--

CREATE UNIQUE INDEX "BookingRequest_rideId_passengerId_key" ON public."BookingRequest" USING btree ("rideId", "passengerId");


--
-- Name: Complaint_complainantId_idx; Type: INDEX; Schema: public; Owner: shafayaturrahman
--

CREATE INDEX "Complaint_complainantId_idx" ON public."Complaint" USING btree ("complainantId");


--
-- Name: Complaint_driverId_idx; Type: INDEX; Schema: public; Owner: shafayaturrahman
--

CREATE INDEX "Complaint_driverId_idx" ON public."Complaint" USING btree ("driverId");


--
-- Name: Complaint_passengerId_idx; Type: INDEX; Schema: public; Owner: shafayaturrahman
--

CREATE INDEX "Complaint_passengerId_idx" ON public."Complaint" USING btree ("passengerId");


--
-- Name: Complaint_rideId_idx; Type: INDEX; Schema: public; Owner: shafayaturrahman
--

CREATE INDEX "Complaint_rideId_idx" ON public."Complaint" USING btree ("rideId");


--
-- Name: Complaint_status_idx; Type: INDEX; Schema: public; Owner: shafayaturrahman
--

CREATE INDEX "Complaint_status_idx" ON public."Complaint" USING btree (status);


--
-- Name: Notification_userId_idx; Type: INDEX; Schema: public; Owner: shafayaturrahman
--

CREATE INDEX "Notification_userId_idx" ON public."Notification" USING btree ("userId");


--
-- Name: User_email_key; Type: INDEX; Schema: public; Owner: shafayaturrahman
--

CREATE UNIQUE INDEX "User_email_key" ON public."User" USING btree (email);


--
-- Name: Warning_complaintId_idx; Type: INDEX; Schema: public; Owner: shafayaturrahman
--

CREATE INDEX "Warning_complaintId_idx" ON public."Warning" USING btree ("complaintId");


--
-- Name: Warning_userId_idx; Type: INDEX; Schema: public; Owner: shafayaturrahman
--

CREATE INDEX "Warning_userId_idx" ON public."Warning" USING btree ("userId");


--
-- Name: BookingRequest BookingRequest_passengerId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."BookingRequest"
    ADD CONSTRAINT "BookingRequest_passengerId_fkey" FOREIGN KEY ("passengerId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: BookingRequest BookingRequest_rideId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."BookingRequest"
    ADD CONSTRAINT "BookingRequest_rideId_fkey" FOREIGN KEY ("rideId") REFERENCES public."Ride"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Complaint Complaint_complainantId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."Complaint"
    ADD CONSTRAINT "Complaint_complainantId_fkey" FOREIGN KEY ("complainantId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: Complaint Complaint_driverId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."Complaint"
    ADD CONSTRAINT "Complaint_driverId_fkey" FOREIGN KEY ("driverId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: Complaint Complaint_passengerId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."Complaint"
    ADD CONSTRAINT "Complaint_passengerId_fkey" FOREIGN KEY ("passengerId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: Complaint Complaint_rideId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."Complaint"
    ADD CONSTRAINT "Complaint_rideId_fkey" FOREIGN KEY ("rideId") REFERENCES public."Ride"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Notification Notification_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."Notification"
    ADD CONSTRAINT "Notification_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Ride Ride_driverId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."Ride"
    ADD CONSTRAINT "Ride_driverId_fkey" FOREIGN KEY ("driverId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: SeatBooking SeatBooking_rideId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."SeatBooking"
    ADD CONSTRAINT "SeatBooking_rideId_fkey" FOREIGN KEY ("rideId") REFERENCES public."Ride"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: SeatBooking SeatBooking_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."SeatBooking"
    ADD CONSTRAINT "SeatBooking_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Warning Warning_complaintId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."Warning"
    ADD CONSTRAINT "Warning_complaintId_fkey" FOREIGN KEY ("complaintId") REFERENCES public."Complaint"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Warning Warning_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: shafayaturrahman
--

ALTER TABLE ONLY public."Warning"
    ADD CONSTRAINT "Warning_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: shafayaturrahman
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;


--
-- PostgreSQL database dump complete
--

\unrestrict cpEiktK42qs4hsH1hZwZKbMIvb3O3C9gqFvYfTRjlZ9OagYHrsgdZPZ2TXNO6IW

